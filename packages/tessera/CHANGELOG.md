## Unreleased

* Statistical aggregates: `Aggregate.stdDev` / `stdDevPopulation` /
  `variance` / `variancePopulation` (Excel's STDEV.S / STDEV.P / VAR.S /
  VAR.P; one Welford accumulator, merged with Chan's formula so parents
  are exact and large means do not cancel), `AggregateKind` entries, cell
  formula names `stdev`, `stdevp`, `var`, `varp`, and strings
  `stdDevOf` … `populationVariance` in every locale.
* Expression language: `Expression` (parse, `check`, `validate`,
  `compile`), `ExpressionScope` (row or cell scope over a `FactTable` or
  `Schema`), `ExpressionError` (kind, source range, arguments),
  `ExprType`, `FunctionRegistry` / `ExpressionFunction` (built-in
  functions plus application ones), the `Expr` syntax tree with
  `toSource`. SQL/Excel-flavoured syntax (`and`, `or`, `not`, `=`, `<>`,
  `in`, `between`, `is empty`, `if()`, `#2024-01-31#` dates, `[quoted
  names]`), static typing, SQL three-valued null handling, day arithmetic
  on dates, closures over the typed column arrays.
* `ExpressionFilter`, `Measure.expression` (`ExpressionMeasure`,
  materialized once per fact table), `ExpressionDimension`,
  `Aggregate.expression` (`ExpressionAggregate`, a cell formula over
  `sum(col)`, `count`, … evaluated per cell) and the `DerivedAggregate`
  base for aggregates computed from other aggregates' results.
* Structured filters `CompareFilter`, `RangeFilter`, `TextFilter`,
  `EmptyFilter` over a column, and `FactFilter.toExpressionSource()` on
  every filter (`null` where it cannot be expressed); `FactFilter.compile`
  binds a filter to a table once per scan.
* Breaking: `Measure` is sealed — `Measure('total')` still constructs a
  `ColumnMeasure`, but `Measure.column` moved to `ColumnMeasure`; every
  measure has `id`, `label`, `labelFor` and `columns`. `Dimension` gained
  `sourceColumns`. `CubeCell.aggregate` also accepts the dependencies of a
  derived aggregate.

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
