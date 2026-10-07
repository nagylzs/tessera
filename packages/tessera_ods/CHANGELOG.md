## 0.2.1

* `OdsTableExporter`: writes an `ExportTable` — plain rows, or a
  `FactTable` through `ExportTable.ofFacts` — as a filterable data table
  rather than a pivot, the counterpart of `XlsxTableExporter`: filter
  buttons over the table (an anonymous database range, as LibreOffice
  writes it), the header frozen and repeated on printed pages, typed
  numbers, booleans and dates (date or date-time by the column's type),
  a number style per `ExportColumn.numberFormat`, content-sized or fixed
  widths, the look from the engine's `TableExportTheme`. Line breaks, tabs
  and runs of spaces in texts are kept.
* Text no longer carries characters XML 1.0 forbids (control characters,
  unpaired surrogates, U+FFFE/U+FFFF), which made the document
  unreadable. Affects `OdsCubeExporter` too.
* Requires `tessera` 0.2.2 (`ExportTable`, `TableExportTheme`).

## 0.2.0

* Requires `tessera` 0.2.0; no changes of its own. Cubes with the new
  aggregates (statistical, cell formulas, "show values as") export like
  any other.

## 0.1.0

* `OdsDataSource`: streams one sheet of an `.ods` document as typed rows
  (floats/ints, dates and date-times, booleans, strings with `text:s`
  and line breaks; repeated columns and rows), sheet selection, skipped
  rows, header-less sheets. Sendable to the import isolate.
* `OdsCubeExporter`: writes a `CubeLayout` as a formatted sheet — merged
  "rotated L" group headers, one column per exported aggregate, level
  fills, fonts and number format from the engine's `CubeExportTheme`,
  content-sized columns, frozen headers.
* `example/main.dart`: command-line round trip on `example/sales.ods`.
* `archive` constraint widened to `>=4.0.7 <5.0.0` so the package resolves next to `package:pdf`.
