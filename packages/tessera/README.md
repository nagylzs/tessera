# tessera

Analyze, group and aggregate tabular data — a pivot-table engine in pure
Dart. Load rows from a CSV file, a list or your own source into a compact
in-memory fact table and view it as a **cube**: a grid whose row and column
headers are hierarchies of dimensions that can be expanded and collapsed,
with an aggregate (sum, average, count, …) in every cell.

This package has no Flutter dependency, so it runs on servers, in
command-line tools, in isolates and in the browser. The widgets that display
and edit a cube live in [`tessera_flutter`](https://pub.dev/packages/tessera_flutter).

> **Status: 0.2.x.** The pipeline works end to end and is covered by tests;
> the API may still change before 1.0 (see the CHANGELOG).

> **User guide:** [github.com/nagylzs/tessera/docs](https://github.com/nagylzs/tessera/blob/main/docs/README.md) — data sources, schema, cubes, aggregates, filters, the expression language, widgets, theming, export, localization, saving, large data.

## What it does

```
                     │ Europe      │ Asia        │ (empty)  │ Total
                     │ + ▸         │ + ▸         │          │
─────────────────────┼─────────────┼─────────────┼──────────┼─────────
 − Electronics       │   120 340   │    98 210   │    4 120 │  222 670
     Laptop          │    80 100   │    60 500   │          │  140 600
     Monitor         │    40 240   │    37 710   │    4 120 │   82 070
 + Furniture         │    55 000   │    12 400   │          │   67 400
 + (empty)           │     3 200   │             │    1 900 │    5 100
─────────────────────┼─────────────┼─────────────┼──────────┼─────────
 Total               │   178 540   │   110 610   │    6 020 │  295 170
```

Rows: `[category, product]`, columns: `[region, country]`, cell:
`sum(total)`. Missing values are first-class: facts without a category land in
an *(empty)* group rather than being dropped, and a cell with no facts stays
blank instead of showing `0`.

## Concepts

| Term | Meaning |
|---|---|
| **DataSource** | Anything that yields rows: column names plus a re-openable row stream. Built in: `CsvDataSource`, `JsonDataSource` (an array of objects), `JsonlDataSource` (JSON Lines, streamed), `ListDataSource`; `tessera_xlsx` and `tessera_ods` add spreadsheets. Implement it to plug in your own format. |
| **Schema / ColumnSpec** | Column types and parsing rules. Inferred from a sample of rows, then adjustable (change a type, exclude a column, supply a date format or a custom parser). |
| **FactTable** | The imported data: immutable, columnar, dictionary-encoded. All rows live in memory. |
| **Dimension** | Something you can group by. Derived from a column: the column value itself, a date part (`date.month`), or any mapping function. |
| **Aggregate** | What a cell shows: `sum`, `average`, `min`, `max`, `count`, `countNonNull`, `distinctCount`, and the variance family `stdDev` / `stdDevPopulation` / `variance` / `variancePopulation` (Excel's STDEV.S / STDEV.P / VAR.S / VAR.P, computed stably in one pass). Implement `Aggregate` for your own, or write a cell formula with `Aggregate.expression`; `percentOf`, `differenceFrom`, `runningTotal` and `rank` show an aggregate against the cells around it. |
| **Measure** | A numeric column you aggregate over (`Measure('total')`), or a number computed per fact by an expression (`Measure.expression('quantity * unit_price')`). Any column can be a dimension; numeric ones can also be measures. |
| **Expression** | A formula in Tessera's small expression language: `total > 100 and region = "Europe"`. Used by `ExpressionFilter`, `Measure.expression`, `ExpressionDimension` and `Aggregate.expression` (a cell formula such as `sum(total) / count`). Parsed, type-checked against the schema and compiled to closures over the columns; see [Expressions](#expressions). |
| **CubeSpec** | Row axis, column axis (each an ordered list of dimensions), the aggregates to compute, and an optional filter. |
| **FactFilter** | Which facts the cube sees. Structured filters (`ValueFilter`, `CompareFilter`, `RangeFilter`, `TextFilter`, `EmptyFilter`, combined with `AndFilter` / `OrFilter` / `NotFilter`) are plain data that render to an expression; `ExpressionFilter` takes any boolean expression; `PredicateFilter` wraps a Dart function. |
| **CubeGrid** | A layout as a rectangular grid of cells (labels, values, merged areas) — what exporters render. |
| **CubeExportTheme** | Fills, fonts and number format of an exported document, as plain ints — shared by the CSV/XLSX/… exporters. |
| **CsvCubeExporter**, **JsonCubeExporter** | Write a layout as CSV text (`export` returns a `String`; `writeTo` streams into a sink) or as JSON records — an array (`export`) or JSON Lines (`exportLines`, `writeLines`), one object per grid row with fields named from the labels. The `tessera_xlsx`, `tessera_ods`, `tessera_html`, `tessera_svg` and `tessera_pdf` packages do the same for their formats. |
| **ExpansionState** | Which groups are expanded on an axis. The summary is the root; the first level is visible when the root is expanded. `Cube.expandRowLevel` / `collapseRowLevel` (and the column twins) open or close a whole level. |
| **CubeLayout** | The visible rows, columns and cells derived from facts + spec + expansion state. |
| **AxisGeometry** | The merged header cells of an axis, for renderers (grids, exporters). |
| **CubeJson / CubeConfig** | JSON form of a pivot configuration (spec, expansion states, schema) for saving and restoring a layout; adapters for custom members. |
| **TesseraSnapshot** | A fact table (and a configuration) as bytes: cache an import or ship a server-built table to clients; format in `docs/snapshot.md`. |
| **TesseraStrings** | Localized texts and label/number formatting rules; fourteen languages built in. |

### Layers

1. **Source & schema** — `DataSource`, `inferSchema`, `ColumnSpec`
2. **Facts** — `FactTableImporter` → `FactTable`; `Dimension`, `Measure`
3. **Cube** — `CubeSpec` + `ExpansionState` → `Cube` → `CubeLayout`

Rendering is a separate concern: `tessera_flutter` draws a `CubeLayout` as
a widget, and exporters can do the same for other targets.

## Usage

```dart
import 'package:tessera/tessera.dart';

// 1. Load. Types are inferred from a sample of rows.
final source = CsvDataSource.fromString(csvText, name: 'sales.csv');
final result = await loadFacts(source);
final facts = result.facts;

// 2. Describe the cube.
final spec = CubeSpec(
  rows: CubeAxis.of([
    const ColumnDimension('category'),
    const ColumnDimension('product'),
  ]),
  columns: CubeAxis.of([
    const DatePartDimension('date', DatePart.year),
    const DatePartDimension('date', DatePart.quarter),
  ]),
  aggregates: [
    Aggregate.sum(const Measure('total')),
    Aggregate.average(const Measure('unit_price')),
    Aggregate.count,
  ],
  filter: ValueFilter(const ColumnDimension('region'), {'Europe', 'Asia'}),
);

// 3. Build the cube and read it.
final cube = Cube(facts: facts, spec: spec);
final cell = cube.layout.cellAt(0, 0);
final revenue = cell.aggregate(Aggregate.sum(const Measure('total')));

// 4. Walk the visible headers, with localized labels.
final strings = TesseraStrings.forLanguage('hu')!;
for (final entry in cube.layout.rows.entries) {
  print('${'  ' * entry.depth}${strings.formatValue(entry.dimension, entry.value)}');
}
```

For big files, import off the main isolate with progress:

```dart
final file = File(path);
final source = CsvDataSource.fromBytes(file.openRead, length: file.lengthSync());
final result = await loadFactsInIsolate(
  source,
  onProgress: (p) {
    print('${p.rowsRead} rows${p.fraction == null ? '' : ' (${(p.fraction! * 100).round()}%)'}');
    return !cancelRequested; // false cancels → ImportCancelled
  },
);
```

The source is sent to the worker isolate, so it must be sendable — plain
data (`CsvDataSource.fromData(bytes)`) or a `File` work; a live stream does
not.

## Expressions

Filters, calculated measures, computed dimensions and cell formulas share
one small, side-effect free expression language, meant for people who
write spreadsheet formulas or SQL `WHERE` clauses:

```dart
// facts where the expression is true (unknown, e.g. an empty total, excludes the fact)
filter: ExpressionFilter('total > 100 and region = "Europe" and year(date) = 2024')

// a number computed per fact, aggregated like a stored column
Aggregate.sum(Measure.expression('quantity * unit_price * (1 - coalesce(discount, 0))', label: 'net'))

// a value computed per fact, grouped like a stored column
ExpressionDimension('if(total > 100, "big", "small")', label: 'size')

// a number computed per cell from the cell's aggregates
Aggregate.expression('sum(total) / count', label: 'per sale')
```

Grammar, loosest binding first: `or`; `and`; `not`; comparisons `=`
(`==`), `<>` (`!=`), `<`, `<=`, `>`, `>=`, `x [not] in (a, b, …)`,
`x [not] between low and high` (inclusive), `x is [not] empty`;
`+`, `-`; `*`, `/`, `%`; unary `-`; then literals, names, calls and
parentheses. Keywords and function names are case-insensitive; column
names are not, and a name with spaces, punctuation or a keyword's spelling
is written in brackets: `[unit price]`, `[and]`. Literals: numbers with a
`.` decimal point (`1.5`, `2e3`), text in double or single quotes with the
quote doubled to escape (`"say ""hi"""`), `true`, `false`, `null`, and
dates as `#2024-01-31#` or `#2024-01-31 10:30:00#` (UTC, like every date in
a fact table).

Types are `number`, `text`, `boolean` and `date`, every one nullable, and
they are checked before anything runs: an unknown column, `qty + region`
or `year(qty)` is an `ExpressionError` with the offending range, which an
editor can show while the user types (`Expression.validate(source, scope:
ExpressionScope.ofSchema(schema), expected: ExprType.boolean)`). Empty
values follow SQL: arithmetic and comparisons with an empty operand are
empty, `and` / `or` use the three-valued truth tables, a filter keeps a
fact only when the expression is `true`, and `x is empty`, `isempty(x)`
and `coalesce(a, b, …)` are the ways to test for and replace them. Dates
support `date + n` / `date - n` (days) and `date - date` (a number of
days); text comparisons are case-sensitive (`lower()` for the other
behaviour); `/` and `%` by zero give empty.

Built-in functions: `if(cond, a, b)`, `coalesce(a, …)`, `isempty(x)`;
`abs`, `round(n[, digits])`, `floor`, `ceil`, `sqrt`, `min(n, …)`,
`max(n, …)`, `number(text)`; `len`, `lower`, `upper`, `trim`, `left(t, n)`,
`right(t, n)`, `substring(t, start[, length])` (1-based), `contains`,
`startswith`, `endswith`, `replace(t, from, to)`, `concat(t, …)`,
`text(number | date | boolean)`; `year`, `quarter`, `month`, `week` (ISO),
`day`, `weekday` (1 = Monday), `hour`, `date(text)`, `date(y, m, d)`,
`today()`. An application adds its own with a `FunctionRegistry`:

```dart
final functions = FunctionRegistry.standard().withFunction(
  ExpressionFunction(
    'vat',
    parameters: [ExprType.number],
    returns: ExprType.number,
    implementation: (args) => (args[0] as double?) == null ? null : (args[0] as double) * 0.27,
  ),
);
ExpressionFilter('vat(total) > 10', functions: functions);
```

Cell formulas (`Aggregate.expression`) refer to aggregates instead of
columns: `sum(x)`, `avg(x)`, `min(x)`, `max(x)`, `count` (facts),
`count(x)` (non-empty values), `stdev(x)`, `stdevp(x)`, `var(x)`,
`varp(x)` and `distinct(x)`, where `x` is a column or any row expression
over the columns — `sum(qty * price) / sum(qty)` is a weighted average,
`distinct(upper(left(country, 1)))` counts initials. The engine
accumulates whatever the formula needs, whether or not the spec lists it,
and evaluates the formula once per cell.

The language has no loops, assignments or I/O, so expressions typed by a
user cannot do harm. Expressions are compiled to closures that read the
fact table's typed arrays directly, are evaluated once per fact per cube
build (filters) or once per fact table (calculated measures and
dimensions, whose values are then stored like a column), and their
canonical text form (`Expression.parse(s).canonicalSource`,
`FactFilter.toExpressionSource()`) is what an application saves.

## Show values as

Layout-relative aggregates present another aggregate's values against
the cells around them, the way Excel's "Show Values As" does. They are
computed from the layout when a cell is read, so they follow expansion
and sorting; the aggregate they are applied to need not be in the spec:

```dart
final revenue = Aggregate.sum(const Measure('total'));
aggregates: [
  revenue,
  Aggregate.percentOf(revenue, TotalOf.row),          // also column, grand, parentRow, parentColumn
  Aggregate.differenceFrom(revenue, axis: AxisSide.columns),   // from the previous column group
  Aggregate.percentDifferenceFrom(revenue, axis: AxisSide.rows, item: const BaseItem.value('Europe')),
  Aggregate.runningTotal(revenue, axis: AxisSide.columns),
  Aggregate.rank(revenue, axis: AxisSide.rows),        // 1 = largest among siblings
]
```

"Previous", "next", running totals and ranks work among the sibling
groups of the cell's own group, in display order; summaries have no
siblings and give `null` (a running total then equals the value itself).
Percent of a missing or zero total is `null`. Sorting by a layout
aggregate sorts by the aggregate it is applied to. Implement
`LayoutAggregate` for your own: it receives a `LayoutCellContext` with
the cell's values, its totals and its siblings.

## Saving a configuration

`CubeJson` turns a pivot configuration into plain JSON data and back, so
an application can persist a layout and restore it over the same source:

```dart
// save
final config = CubeConfig.of(cube, schema: editedSchema); // schema optional
final text = jsonEncode(CubeJson.standard.encodeConfig(config));

// restore
final restored = CubeJson.standard.decodeConfig(jsonDecode(text) as Map<String, Object?>);
final facts = (await loadFacts(source, schema: restored.schema)).facts;
final cube = restored.toCube(facts);
```

A `CubeConfig` bundles the `CubeSpec` (axes with sorts, aggregates,
filter), both `ExpansionState`s and the `Schema`. Every built-in
dimension, measure, aggregate and filter has a JSON form, expressions are
stored as their source text, dates as `{"date": "…"}`, and expansion paths
as lists of values positional against their axis. Application-defined
aggregates, dimensions and filters plug in through a `JsonAdapter`; a
`FunctionRegistry` given to the codec reaches every decoded expression. A
`PredicateFilter`, a `MappedDimension` or a `ColumnSpec.parser` is a Dart
function and cannot be stored: the first two throw without an adapter, the
parser is dropped.

## Snapshots

`TesseraSnapshot` writes an imported fact table — and optionally a
`CubeConfig` — as one buffer of bytes that loads back in a copy, with no
parsing and no inference. Use it to cache an import, or to import on a
server and send the table to clients so they never see the source file:

```dart
// server, or first open
final bytes = const TesseraSnapshot().encode(facts, config: CubeConfig.of(cube));

// client, or next open
final contents = const TesseraSnapshot().decode(bytes);
final cube = contents.config!.toCube(contents.facts);
```

On the 2 M-row benchmark set the snapshot is 106 MB, encodes in about
40 ms and decodes in about 60 ms, where parsing and importing the CSV take
8 s. The format is a JSON header followed by the raw little-endian column
arrays, documented in [docs/snapshot.md](https://github.com/nagylzs/tessera/blob/main/docs/snapshot.md) so other
software can write it; nothing is compressed — leave that to the transport
(`Content-Encoding: gzip`) or the file layer. `decode` validates every
section and throws `FormatException` on malformed input, including a
snapshot newer than the library.

## Example

[`example/main.dart`](example/main.dart) is the engine end to end from the
command line: read `example/sales.csv`, infer and import, build a
region/country × year/quarter cube with every region expanded, print it,
and write it back as `sales_pivot.csv`:

```
dart run example/main.dart [input.csv] [output.csv]
```

## Contributing

Issues and pull requests are welcome at
<https://github.com/nagylzs/tessera>. Run `dart analyze` and `dart test`
before submitting.

## Author

László Zsolt Nagy <nagylzs@gmail.com>

## License

MIT — see [LICENSE](LICENSE).
