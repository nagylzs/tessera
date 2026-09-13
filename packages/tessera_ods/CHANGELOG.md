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
