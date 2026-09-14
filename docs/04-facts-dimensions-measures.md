# 4. Facts, dimensions and measures

## The fact table

The import produces a `FactTable`: every row of the source as a *fact*,
stored column by column in typed arrays — numbers and dates in
`Float64List`s, text as dictionary codes, booleans as bytes. It is
immutable and compact (a million rows of the sales file is about 100 MB),
and because it is plain typed data it can be moved between isolates and
written as a [snapshot](13-saving.md).

```dart
facts.rowCount;                        // 1000
facts.columns.map((c) => c.name);      // id, date, region, …
facts.column('total').type;            // ColumnType.number
facts.column('total').label;           // from the schema, else the name
facts.column('country').nullCount;     // how many facts have no country
facts.column('country').distinctCount;
facts.valueAt(42, 'country');          // 'Germany', or null
facts.withLabels({'total': 'Revenue'}); // a copy sharing the data, relabelled
```

You rarely read a fact table row by row; the cube does that. What you do
is describe *views* on its columns.

## Dimensions: what to group by

A `Dimension` is derived from a column but is not the column. Three kinds
are built in, and a fourth is computed by an expression:

```dart
const ColumnDimension('country');                        // the value itself
const DatePartDimension('date', DatePart.quarter);       // year, quarter, month, week (ISO), day, weekday, hour
MappedDimension(                                         // any function of the value
  id: 'price_band',
  sourceColumn: 'unit_price',
  map: (v) => v == null ? null : (v as num) < 100 ? 'under 100' : '100 and up',
);
ExpressionDimension('if(total > 500, "big", "small")', label: 'size');   // see the expression chapter
```

Points worth knowing:

- Two dimensions of the same column can sit on different axes: `date.year`
  on the columns, `date.month` on the rows. The same dimension cannot
  appear twice.
- Date parts are integers (month 1–12, weekday 1–7 with Monday = 1) so
  they sort chronologically; the localized strings turn them into names
  and `Q1`…`Q4` for display.
- A `null` column value is a group of its own, labelled "(empty)", not a
  dropped fact. That is a deliberate design decision: the empty group is
  often the interesting one.
- Dimensions are value objects identified by `id`. Two
  `ColumnDimension('country')` instances are equal.
- `standardDimensions(facts)` lists every column as a dimension plus
  every date part of every date column — what the dimension picker
  offers.

A `MappedDimension` is a Dart closure, so it cannot be saved as JSON; an
`ExpressionDimension` can, and usually expresses the same thing.

## Measures: what to aggregate

A `Measure` names a numeric column, or a number computed per fact:

```dart
const Measure('total');
const Measure('unit_price', label: 'Price');
Measure.expression('quantity * unit_price * (1 - coalesce(discount, 0))', label: 'net');
```

Any numeric column can be a measure *and* a dimension: `quantity` summed
in the cells and grouped on the rows at the same time is legitimate.

An expression measure is computed once per fact table on first use and
then read like a stored column, so aggregating it costs the same as a
plain one. `standardMeasures(facts)` lists the numeric columns.

## Labels

Every dimension, measure and aggregate has a `label` (standalone) and a
`labelFor(facts)` that resolves the column's label from the schema. The
widgets always use the latter, so relabelling a column shows up in chips,
headers and exports. Localized composition ("sum of Revenue" in English,
"Revenue összege" in Hungarian) is a `TesseraStrings` concern; a label
you give explicitly is used as is.
