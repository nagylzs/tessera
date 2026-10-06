# tessera_xlsx

Excel (`.xlsx`) support for the [tessera](../tessera) pivot-table engine:

* `XlsxDataSource` — a `DataSource` that streams the rows of one worksheet,
  so a workbook can be inferred and imported like a CSV file (including in
  an isolate, via `loadFactsInIsolate`).
* `XlsxCubeExporter` — writes a `CubeLayout` (the expanded rows and
  columns exactly as shown) as a formatted worksheet: merged group headers
  in the "rotated L" shape, level shading, bold summaries, frozen headers,
  localized labels through `TesseraStrings`. The engine's
  `CubeExportTheme` (shared with the other exporters) sets fills, borders,
  fonts and the number format with plain ARGB ints — no Flutter types;
  `CubeExportTheme.brand(primary: 0xFF00695C)` derives a whole theme from
  one company colour, `gradient` builds level fills. Excel-only choices
  (`numberFormatCode`, `freezeHeaders`, column-width bounds) are on the
  exporter.
* `XlsxTableExporter` — writes an `ExportTable` (plain rows, or a whole
  `FactTable` through `ExportTable.ofFacts`) as a filterable data table
  rather than a pivot: a bold header row with an **autofilter** over the
  table, the header frozen, real numbers, booleans and dates, a number
  format per column (the engine's `NumberFormat`, or a native Excel code
  such as `#,##0 "Ft"`), content-sized columns, optional borders. What an
  app hands over when the user wants "the grid in Excel". `tessera_ods`
  and the engine's `CsvTableExporter` take the same `ExportTable`.

Pure Dart, no Flutter dependency — works in Flutter apps, on servers and in
command-line tools alike. Both directions live in one package because they
share the same OOXML machinery.

Both directions are implemented and tested (the exporter's output is
verified by opening it with LibreOffice in the tests).

```dart
import 'package:tessera_xlsx/tessera_xlsx.dart';

final source = XlsxDataSource.fromData(bytes, name: 'sales.xlsx');
final result = await loadFacts(source);

final xlsx = XlsxCubeExporter(strings: TesseraStrings.forLanguage('hu')!)
    .export(cube.layout);

final table = const XlsxTableExporter().export(
  const ExportTable([
    ExportColumn('Name'),
    ExportColumn('Amount', numberFormat: NumberFormat(decimals: 2)),
  ], [
    ['Anna', 1234.5],
    ['Béla', 99.0],
  ]),
);
final facts = const XlsxTableExporter().export(
  ExportTable.ofFacts(result.facts, filter: cube.spec.filter),
);
```

`export` returns the workbook as a `Uint8List`, ready to write to a file
or hand to a download.

> **User guide:** [github.com/nagylzs/tessera/docs](https://github.com/nagylzs/tessera/blob/main/docs/README.md) — data sources, schema, cubes, aggregates, filters, the expression language, widgets, theming, export, localization, saving, large data.

## Example

[`example/main.dart`](example/main.dart) does the whole round trip from
the command line — read `example/sales.xlsx`, infer and import, build a
region/country × year/quarter cube with every region expanded, write it
as `sales_pivot.xlsx`:

```
dart run example/main.dart [input.xlsx] [output.xlsx]
```

## License

MIT — see [LICENSE](LICENSE). Author: László Zsolt Nagy.
