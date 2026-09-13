## 0.0.1

* Initial release: data sources (CSV, lists), schema inference, the fact
  table importer, cubes with expandable row/column hierarchies, built-in
  aggregates, `AxisGeometry` for renderers, and `TesseraStrings` with
  fourteen built-in languages.
* `Cube.expandRowLevel` / `collapseRowLevel` / `expandColumnLevel` /
  `collapseColumnLevel` open or close every group of one level (keeping
  deeper expansions), `rowsAddedByExpandingLevel` /
  `columnsAddedByExpandingLevel` count the effect beforehand;
  `ExpansionState.collapseLevel`. Strings `sortAscending`,
  `sortDescending`, `expandAll`, `collapseAll`, `inheritSort`.
* `AxisDimension.sort` is nullable: `null` inherits the ordering of the
  level above (`CubeAxis.sortAt` resolves it), so an aggregate sort on the
  first level orders every level.
