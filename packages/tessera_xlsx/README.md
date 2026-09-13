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
```

`export` returns the workbook as a `Uint8List`, ready to write to a file
or hand to a download.

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
