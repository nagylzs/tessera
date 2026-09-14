# 8. The expression language

Filters, calculated measures, computed dimensions and cell formulas share
one small formula language, meant for people who write spreadsheet
formulas or SQL `WHERE` clauses. It has no loops, assignments or I/O, so
an expression typed by a user cannot do harm; it is type-checked before
anything runs, so an editor can point at a mistake while the user types;
and it is compiled to closures over the fact table's columns, so
evaluating a million facts is a fraction of a second.

```
total > 500 and region in ("Europe", "Asia")            filter
quantity * unit_price * (1 - coalesce(discount, 0))      calculated measure
if(total > 500, "big", "small")                          computed dimension
sum(total) / sum(quantity)                               cell formula
```

## Where expressions go

| Use | API | Scope |
|---|---|---|
| Filter | `ExpressionFilter(source)` | one fact; must be boolean |
| Calculated measure | `Measure.expression(source)` | one fact; must be a number |
| Computed dimension | `ExpressionDimension(source)` | one fact; any type |
| Cell formula | `Aggregate.expression(source)` | one cell; names are aggregates; must be a number |

The first three see the columns of the fact table by name. A cell
formula sees `sum(x)`, `avg(x)`, `min(x)`, `max(x)`, `count`, `count(x)`,
`stdev(x)`, `stdevp(x)`, `var(x)`, `varp(x)` and `distinct(x)` instead,
where `x` is a column or a row expression.

## Grammar

Loosest binding first:

| Level | Operators |
|---|---|
| `or` | |
| `and` | |
| `not` | |
| comparison | `=` (`==`), `<>` (`!=`), `<`, `<=`, `>`, `>=`, `x [not] in (a, b, …)`, `x [not] between low and high` (inclusive), `x is [not] empty` |
| additive | `+`, `-` |
| multiplicative | `*`, `/`, `%` |
| unary | `-` |
| primary | literals, names, `f(args)`, `(…)` |

Keywords and function names are case-insensitive (`AND`, `Year(...)`);
column names are not. A name with spaces, punctuation or a keyword's
spelling goes in brackets: `[unit price]`, `[and]`; a `]` inside is
doubled.

Literals: numbers with a `.` decimal point (`1.5`, `2e3`); text in
double or single quotes with the quote doubled to escape (`"say
""hi"""`, `'it''s'`); `true`, `false`, `null`; dates as `#2024-01-31#`
or `#2024-01-31 10:30:00#`, always UTC, like every date in a fact table.

Stored expressions are locale-neutral: English function names, a `.`
decimal point, ISO dates. An editor may display something else, but this
is what is saved.

## Types

Four types, every one nullable: `number`, `text`, `boolean`, `date`.
Integer and number columns are both `number`; date and dateTime columns
are both `date`.

The checker infers a type for every node before anything runs and
rejects what does not fit: an unknown column, `quantity + region`,
`year(quantity)`, `if(total, 1, 2)` (a number where a boolean is needed),
`region < "M"` is fine (text is ordered), `active < true` is not. Errors
are `ExpressionError`s with a `kind`, a source `offset` and `length` and
the offending names, plus an English `message`; `TesseraStrings.expressionError`
gives the localized one.

```dart
final error = Expression.validate('year(quantity) = 2024',
    scope: ExpressionScope.ofFacts(facts), expected: ExprType.boolean);
// argument 1 of year must be date, not number  (offset 5, length 8)
```

## Empty values

Empty follows SQL's three-valued logic:

- Arithmetic and comparison with an empty operand are empty:
  `discount * 2` and `discount > 0` are empty when the discount is.
- `and` / `or` use the three-valued truth tables: `false and empty` is
  `false`, `true or empty` is `true`, `true and empty` is empty.
- A filter keeps a fact only when its expression is `true`. `discount > 0`
  therefore drops facts with no discount; `discount > 0 or discount is
  empty` keeps them.
- `x is empty` / `x is not empty` / `isempty(x)` test; `coalesce(a, b, …)`
  takes the first non-empty argument.
- `=` and `in` compare values; `country = null` is empty, never true, so
  matching the "(empty)" group is `country is empty`.
- `/` and `%` by zero give empty rather than infinity.

Text comparisons are case-sensitive; use `lower()` on both sides for the
other behaviour. Dates support `date + n` and `date - n` (days) and `date1
- date2` (a number of days).

## Functions

| Group | Functions |
|---|---|
| Conditional | `if(cond, a, b)`, `coalesce(a, …)`, `isempty(x)` |
| Numbers | `abs`, `round(n[, digits])`, `floor`, `ceil`, `sqrt`, `min(n, …)`, `max(n, …)`, `number(text)` |
| Text | `len`, `lower`, `upper`, `trim`, `left(t, n)`, `right(t, n)`, `substring(t, start[, length])` (1-based), `contains`, `startswith`, `endswith`, `replace(t, from, to)`, `concat(t, …)`, `text(number \| date \| boolean)` |
| Dates | `year`, `quarter`, `month`, `week` (ISO), `day`, `weekday` (1 = Monday), `hour`, `date(text)`, `date(y, m, d)`, `today()` |

`round(1234.5, -2)` is `1200`; `text(1.5)` is `"1.5"` and `text(#2024-01-31#)`
is `"2024-01-31"`; `number("x")` is empty; `today()` is fixed when the
expression is compiled.

### Application functions

Register your own with a `FunctionRegistry`; the checker treats them like
built-ins and they may be overloaded by parameter types:

```dart
final functions = FunctionRegistry.standard().withFunction(
  ExpressionFunction(
    'vat',
    parameters: [ExprType.number],
    returns: ExprType.number,
    implementation: (args) {
      final v = args[0] as double?;      // numbers arrive as double?, text as String?,
      return v == null ? null : v * 0.27; // booleans as bool?, dates as UTC DateTime?
    },
  ),
);
ExpressionFilter('vat(total) > 100', functions: functions);
Measure.expression('vat(total)', functions: functions);
```

The implementation must be pure: it is called once per fact, in any
order. Pass the same registry to `CubeJson` and to the widgets
(`AggregateEditor.functions`, `showFilterEditor(functions:)`) so
restored and edited expressions resolve it.

## Programmatic use

```dart
final expr = Expression.parse('quantity * unit_price');   // ExpressionError on a syntax error
expr.names;                                                // {quantity, unit_price}
expr.canonicalSource;                                      // normalized text, what to store
final checked = expr.check(ExpressionScope.ofFacts(facts));  // types resolved
final compiled = expr.compile(facts);                      // closures over the columns
compiled.asNumber(row);                                    // double, NaN for empty
compiled.evaluate(row);                                    // boxed: double?, String?, bool?, DateTime?
```

`ExpressionScope.ofSchema(schema)` validates before any data is imported
— what a settings screen would use. `ExpressionField` in
`tessera_flutter` is a text field that does the validation and
underlining for you.
