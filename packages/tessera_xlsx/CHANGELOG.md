## 0.0.1

* `XlsxDataSource`: streams one worksheet as typed rows (shared, inline
  and formula strings, numbers, dates by style, booleans), sheet
  selection, skipped rows, header-less sheets, row estimate from the
  sheet dimension. Sendable to the import isolate.
* `XlsxCubeExporter`: writes a `CubeLayout` as a worksheet — merged
  "rotated L" group headers, one column per exported aggregate, level
  fills, bold summaries, thin borders, number format, content-sized
  columns, frozen panes; `XlsxCubeStyle`, localized labels and overrides.
