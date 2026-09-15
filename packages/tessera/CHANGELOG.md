## Unreleased

* `JsonDataSource` (a JSON array of objects, parsed whole) and
  `JsonlDataSource` (JSON Lines, streamed with a row estimate), with
  `JsonOptions`: nested objects flattened into dotted columns (or kept as
  JSON text), arrays as JSON text, `columns` to name the columns,
  `scanAllRows` to union every record's keys. Values keep their JSON
  types; strings go through the schema's parsers like CSV cells.
* `JsonFactExporter`: a `FactTable` as records — one object per fact with
  a field per column (`columns` to pick, `useLabels` for label keys) —
  as a JSON array (`export`, optionally indented) or JSON Lines
  (`exportLines`, `writeLines` streams row by row; `records` is lazy).
  Integers stay integers, dates become ISO text, so `JsonlDataSource`
  reads the table back with its types.
* The default date formats also recognize the full ISO 8601 forms JSON
  producers write: `yyyy-MM-ddTHH:mm:ss.SSS`, with or without a trailing
  `Z`.
* `JsonCubeExporter`: a layout as records — one object per grid row, the
  row dimensions as fields named after their titles, one field per column
  entry and aggregate named from the labels — as a JSON array (`export`,
  optionally indented) or JSON Lines (`exportLines`, `writeLines`);
  `records` gives the objects. `JsonExportOptions`: group labels repeated
  (default) or once per group, the path separator, the indent.
* Chart series: `ChartData` (categories × series of doubles) and
  `ScatterData` ((x, y) points in series) for feeding any chart library.
  `fromLayout` reads a layout's cells as displayed (`ChartEntries`
  selects the entries: visible leaves by default, one level, given
  paths, or all), `fromFacts` builds a one- or two-dimensional cube for
  the purpose, `fromCell` drills into the facts behind one cell by
  another dimension, `ScatterData.ofFacts` plots individual facts (two
  measures, optional series dimension, row set and limit). Categories
  carry the raw dimension value (`DateTime`, `int`, `double` …) and
  `periodStart` composes nested date parts for a time axis;
  `withoutEmpty()`, `transposed()`. `Coordinate.toFilter()` and
  `cellFilter(layout, cell)` give the filter behind a cell.
* Continuous integration: a GitHub Actions workflow
  (`.github/workflows/ci.yml` at the repository root) runs the analyzer,
  the format check and every package's tests on each push and pull
  request, with LibreOffice, poppler, qpdf, ghostscript, librsvg and Noto
  Sans installed so the exporter round-trip tests run rather than skip.

## 0.2.0

The expression language and everything built on it. One breaking change.

### Breaking

* `Measure` is sealed: `Measure('total')` still constructs a
  `ColumnMeasure`, but `Measure.column` moved to `ColumnMeasure`; every
  measure has `id`, `label`, `explicitLabel`, `labelFor` and `columns`.
  `Dimension` gained `sourceColumns`. `AxisSide` now lives in the engine
  (`tessera_flutter` re-exports it, so no import change there).

### Expression language

* `Expression` (parse, `check`, `validate`, `compile`), `ExpressionScope`
  (row or cell scope over a `FactTable` or `Schema`), `ExpressionError`
  (kind, source range, arguments), `ExprType`, `FunctionRegistry` /
  `ExpressionFunction` (built-in functions plus application ones), the
  `Expr` syntax tree with `toSource`. SQL/Excel-flavoured syntax (`and`,
  `or`, `not`, `=`, `<>`, `in`, `between`, `is empty`, `if()`,
  `#2024-01-31#` dates, `[quoted names]`), static typing, SQL
  three-valued null handling, day arithmetic on dates, compiled to
  closures over the typed column arrays. `TesseraStrings.expressionError`
  gives the message in every locale.
* Plug points: `ExpressionFilter`; `Measure.expression`
  (`ExpressionMeasure`, materialized once per fact table);
  `ExpressionDimension`; `Aggregate.expression` (`ExpressionAggregate`, a
  cell formula over `sum(x)`, `avg(x)`, `count`, `count(x)`, `min`,
  `max`, `stdev`, `stdevp`, `var`, `varp` and `distinct(x)`, where `x` is
  a column or any row expression — `sum(qty * price) / sum(qty)`), and the
  `DerivedAggregate` base for aggregates computed from other aggregates'
  results.

### Aggregates

* Statistical: `Aggregate.stdDev` / `stdDevPopulation` / `variance` /
  `variancePopulation` (Excel's STDEV.S / STDEV.P / VAR.S / VAR.P), one
  Welford accumulator merged with Chan's formula so parents are exact and
  large means do not cancel.
* Layout-relative ("Show Values As"): `Aggregate.percentOf` (`TotalOf.row`
  / `column` / `grand` / `parentRow` / `parentColumn`), `differenceFrom`
  and `percentDifferenceFrom` (`BaseItem.previous` / `next` / `value(v)`
  along an `AxisSide`), `runningTotal`, `rank`; the `LayoutAggregate`
  base with `LayoutCellContext` for custom ones; `ValueDisplay` names the
  ready-made choices for pickers. Computed when a cell is read; sorting
  by one sorts by its base. `CubeCell.aggregate` also accepts the
  dependencies of a derived aggregate.
* `AggregateKind` covers the new kinds; every label is localized.

### Filters

* Structured filters `CompareFilter`, `RangeFilter`, `TextFilter`,
  `EmptyFilter` over a column, equal by value like `ValueFilter`,
  `AndFilter`, `OrFilter` and `NotFilter` now are.
  `FactFilter.toExpressionSource()` on every filter (`null` where it
  cannot be expressed); `FactFilter.compile` binds a filter to a table
  once per scan.

### Saving and transport

* `CubeJson`: JSON encoding and decoding of `CubeConfig` (a bundle of
  `CubeSpec`, both `ExpansionState`s and the `Schema`; `CubeConfig.of(cube)`,
  `toCube(facts)`) and of every part on its own. `JsonAdapter` for custom
  aggregates, dimensions and filters; `functions` for decoded expressions;
  `FormatException` on malformed input, `UnsupportedError` for members
  without a JSON form.
* `TesseraSnapshot`: a `FactTable` (and optionally a `CubeConfig`) as one
  `Uint8List` — JSON header, raw little-endian column arrays — that
  `decode` loads back in a copy after validating every section. The
  format is specified in `docs/snapshot.md` for other writers. 2 M rows:
  106 MB, ~40 ms to encode, ~60 ms to decode.

### Strings

* New members for the filter editor, the aggregate picker's formula and
  label fields, "show values as", the statistical and layout-relative
  aggregate labels, and expression errors, in all fourteen locales. The
  count-of-facts function is "Count of records" in the picker (it said
  "rows" in most locales, which clashed with the cube's rows).

## 0.1.1

* README: the status note no longer says the package is unpublished.

## 0.1.0

* Initial release: data sources (CSV, lists), schema inference, the fact
  table importer, cubes with expandable row/column hierarchies, built-in
  aggregates, `AxisGeometry` for renderers, and `TesseraStrings` with
  fourteen built-in languages.
* `Cube.expandRowLevel` / `collapseRowLevel` / `expandColumnLevel` /
  `collapseColumnLevel` open or close every group of one level (keeping
  deeper expansions), `rowsAddedByExpandingLevel` /
  `columnsAddedByExpandingLevel` count the effect beforehand;
  `ExpansionState.collapseLevel`. Strings `sortAscending`,
  `sortDescending`, `expandAll`, `collapseAll`, `inheritSort`,
  `totalsAtEnd`, `totalsAtStart`, `totalsHidden`, `subtotalsAbove`,
  `subtotalsBelow`, `subtotalsLeft`, `subtotalsRight`, `subtotalsHidden`.
* `CubeAxis.subtotalPosition` (`SubtotalPosition.top` / `bottom` /
  `hidden`): where an expanded group's own row goes; `AxisLayout.entryFor`
  resolves groups without a row; `HeaderArea.path`.
* `CubeGrid`: a `CubeLayout` as a rectangular grid of typed cells with
  merged areas, the way `CubeView` shows it — what exporters render from.
* `CubeExportTheme` / `ExportFont` / `NumberFormat`: the format-neutral
  look of an exported document (fills, border, fonts per role, number
  format; `brand(primary:)`, `gradient`, `mix`), shared by every exporter.
* `Oklch` (perceptual colour, to/from ARGB, gamut clipping) and
  `HueLevels`: nesting levels coloured by hue alone at one lightness,
  headers the same hue with more chroma, golden-angle steps so adding a
  level keeps the others' colours. `CubeExportTheme.hueLevels`,
  `rowHeaderFills` / `columnHeaderFills` per level, `levelBasis`
  (`combined` / `row`), `fillOf` / `fontOf` for exporters;
  `GridCell.rowLevel` / `columnLevel`.
* `GridMetrics`: pixel geometry of a `CubeGrid` (content-sized column
  widths from an estimate or a `TextMeasurer`, row heights from the
  fonts, offsets) for renderers that lay cells out themselves;
  `GridPagination` cuts it into pages with repeated header rows and
  columns; `NumberFormat.format(value, strings)`.
* `CsvCubeExporter` (`CsvExportOptions`: delimiter, quote, line ending,
  decimal separator, BOM, group labels at the origin or repeated).
* `FactTable.withLabels` relabels columns without a re-import (data is
  shared).
* `AxisDimension.sort` is nullable: `null` inherits the ordering of the
  level above (`CubeAxis.sortAt` resolves it), so an aggregate sort on the
  first level orders every level.
