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
