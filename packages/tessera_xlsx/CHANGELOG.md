## 0.2.1

* `XlsxTableExporter`: writes an `ExportTable` — plain rows, or a
  `FactTable` through `ExportTable.ofFacts` — as a filterable data table
  rather than a pivot: header row with an autofilter over the table (plus
  the `_xlnm._FilterDatabase` defined name), frozen header, numbers,
  booleans and real Excel dates (date or date-time by the column's type),
  a number format per column from `ExportColumn.numberFormat` or a native
  Excel code through `formatCodes`, content-sized or fixed widths, header
  fill, fonts and borders from the engine's `TableExportTheme`. Excel's
  limits are enforced: more than 1 048 575 rows or 16 384 columns throw
  an `ArgumentError`, longer texts than 32 767 characters are cut; dates
  before 1900 are written as ISO text, and January–February 1900 get
  Excel's serials despite its 1900 leap-year bug.
* The writer's text no longer carries characters XML 1.0 forbids (control
  characters, unpaired surrogates, U+FFFE/U+FFFF): one such character in a
  value made the whole sheet unreadable. Affects `XlsxCubeExporter` too.
* Requires `tessera` 0.2.2 (`ExportTable`, `TableExportTheme`).

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
