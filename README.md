# tessera

Analyze, group and aggregate tabular data in Flutter — a pivot-table engine
with a widget on top.

> **Status: early development.** The pipeline works end to end (CSV →
> facts → cube → widget) and is covered by tests, but the API is still
> moving and nothing is published to pub.dev yet.

## What it does

Tessera takes any row-oriented data source (a CSV file, a list of Dart
objects, your own iterator), loads it into a compact in-memory fact table, and
lets you view it as a **cube**: a grid whose row and column headers are
hierarchies of dimensions that can be expanded and collapsed, with an
aggregate (sum, average, count, …) in every cell.

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
| **DataSource** | Anything that yields rows: column names plus a re-openable row stream. Implement it to plug in your own format. |
| **Schema / ColumnSpec** | Column types and parsing rules. Inferred from a sample of rows, then adjustable (change a type, exclude a column, supply a date format or a custom parser). |
| **FactTable** | The imported data: immutable, columnar, dictionary-encoded. All rows live in memory. |
| **Dimension** | Something you can group by. Derived from a column: the column value itself, a date part (`date.month`), or any mapping function. |
| **Measure** | A numeric column you aggregate over. Any column can be a dimension; numeric ones can also be measures. |
| **CubeSpec** | Row axis, column axis (each an ordered list of dimensions), the aggregates to compute, and an optional filter. |
| **ExpansionState** | Which groups are expanded on an axis. The summary is the root; the first level is visible when the root is expanded. |
| **CubeLayout** | The visible rows, columns and cells derived from facts + spec + expansion state. |
| **CubeView** | The Flutter widget that renders a cube and drives expand/collapse. |

### Layers

1. **Source & schema** — `DataSource`, `inferSchema`, `ColumnSpec`
2. **Facts** — `FactTableImporter` → `FactTable`; `Dimension`, `Measure`
3. **Cube** — `CubeSpec` + `ExpansionState` → `Cube` → `CubeLayout`
4. **Widgets** — `CubeController`, `CubeView`

Layers 1–3 do not depend on Flutter and are fully testable with plain Dart.

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

// 4. Or display it.
CubeView(
  controller: CubeController(cube),
  aggregate: Aggregate.sum(const Measure('total')),
  formatCell: (cell, value) => myNumberFormat.format(value),
);
```

For big files, import off the UI isolate with progress:

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

Plain Dart programs can import `package:tessera/core.dart`, which has no
Flutter dependency.

`CubeView` renders lazily (it is built on `TableView` from
`two_dimensional_scrollables`), so large cubes scroll cheaply. Expand and
collapse groups with the `+`/`−` icons; tap a dimension name to sort that
level by value, or the aggregate name under a column to sort the rows by
that column. Colours, sizes and text styles come from a `CubeTheme` and
default to the ambient Material theme.

## Example app

`example/` is one Flutter app with a launcher page listing several
examples (`example/lib/examples.dart`). *Simple pivot* (`example/lib/simple/`)
loads `example/assets/sales.csv` (1 000 generated sales rows with deliberately
missing values, hierarchical dimensions and orphan values — see
`example/tool/gen_sales_csv.dart`) and lets you configure everything
interactively: the inferred schema (include, type, label, date format,
number syntax per column), the axes (drag-and-drop), the aggregates, the
language, and the cube itself.

```bash
cd example && flutter run
```

## Contributing

Issues and pull requests are welcome at
<https://github.com/nagylzs/tessera>. Run `flutter analyze` and `flutter test`
before submitting.

## Author

László Zsolt Nagy <nagylzs@gmail.com>

## License

MIT — see [LICENSE](LICENSE).
