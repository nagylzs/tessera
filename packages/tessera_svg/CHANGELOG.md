## 0.0.1

* Initial release: `SvgCubeExporter` draws a `CubeLayout` as an SVG
  image rendered from `CubeGrid` — merged group headers, one column per
  exported aggregate, fills and fonts from the engine's
  `CubeExportTheme`, localized labels and numbers, text clipped to its
  cell, content-sized columns from `GridMetrics` (an optional
  `measureText` callback replaces the estimate).
* `example/main.dart`: command-line export of `example/sales.csv`.
