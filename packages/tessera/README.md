# tessera

Analyze, group and aggregate tabular data — a pivot-table engine in pure
Dart. Load rows from a CSV file, a list or your own source into a compact
in-memory fact table and view it as a **cube**: a grid whose row and column
headers are hierarchies of dimensions that can be expanded and collapsed,
with an aggregate (sum, average, count, …) in every cell.

This package has no Flutter dependency, so it runs on servers, in
command-line tools, in isolates and in the browser. The widgets that display
and edit a cube live in [`tessera_flutter`](https://pub.dev/packages/tessera_flutter).

> **Status: early development.** The pipeline works end to end and is
> covered by tests, but the API is still moving and nothing is published to
> pub.dev yet.

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
| **DataSource** | Anything that yields rows: column names plus a re-openable row stream. Implement it to plug in your own format. |
| **Schema / ColumnSpec** | Column types and parsing rules. Inferred from a sample of rows, then adjustable (change a type, exclude a column, supply a date format or a custom parser). |
| **FactTable** | The imported data: immutable, columnar, dictionary-encoded. All rows live in memory. |
| **Dimension** | Something you can group by. Derived from a column: the column value itself, a date part (`date.month`), or any mapping function. |
| **Measure** | A numeric column you aggregate over. Any column can be a dimension; numeric ones can also be measures. |
| **CubeSpec** | Row axis, column axis (each an ordered list of dimensions), the aggregates to compute, and an optional filter. |
| **ExpansionState** | Which groups are expanded on an axis. The summary is the root; the first level is visible when the root is expanded. `Cube.expandRowLevel` / `collapseRowLevel` (and the column twins) open or close a whole level. |
| **CubeLayout** | The visible rows, columns and cells derived from facts + spec + expansion state. |
| **AxisGeometry** | The merged header cells of an axis, for renderers (grids, exporters). |
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

## Contributing

Issues and pull requests are welcome at
<https://github.com/nagylzs/tessera>. Run `dart analyze` and `dart test`
before submitting.

## Author

László Zsolt Nagy <nagylzs@gmail.com>

## License

MIT — see [LICENSE](LICENSE).
