## 0.2.0

* Requires `tessera` 0.2.0; no changes of its own. Cubes with the new
  aggregates (statistical, cell formulas, "show values as") export like
  any other.

## 0.1.0

* `XlsxDataSource`: streams one worksheet as typed rows (shared, inline
  and formula strings, numbers, dates by style, booleans), sheet
  selection, skipped rows, header-less sheets, row estimate from the
  sheet dimension. Sendable to the import isolate.
* `XlsxCubeExporter`: writes a `CubeLayout` as a worksheet — merged
  "rotated L" group headers, one column per exported aggregate, level
  fills, bold summaries, thin borders, number format, content-sized
  columns, frozen panes; themed with the engine's `CubeExportTheme`
  (`numberFormatCode`, `freezeHeaders` and the width bounds are exporter
  options), localized labels and overrides.
  Follows the axes' summary and subtotal positions — with both hidden the
  export is a flat table of leaf rows.
* The exporter renders from the engine's `CubeGrid`.
* `example/main.dart`: command-line round trip on `example/sales.xlsx`.
* `archive` constraint widened to `>=4.0.7 <5.0.0` so the package resolves next to `package:pdf`.
