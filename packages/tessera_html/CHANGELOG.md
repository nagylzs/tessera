## 0.1.0

* `HtmlCubeExporter`: writes a `CubeLayout` as an HTML table — merged
  "rotated L" group headers (`rowspan`/`colspan`), one column per
  exported aggregate, classes per cell kind and level, a stylesheet from
  the engine's `CubeExportTheme` (embedded, inline or none), sticky
  headers, a whole document or a fragment, localized labels and numbers.
* `example/main.dart`: command-line round trip on `example/sales.csv`.
* Header cells carry `row-level-N` / `col-level-N` classes and the
  stylesheet colours them from the theme's `rowHeaderFills` /
  `columnHeaderFills`; data cells follow the theme's `levelBasis`.
