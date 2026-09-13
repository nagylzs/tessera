# tessera_xlsx

Excel (`.xlsx`) support for the [tessera](../tessera) pivot-table engine:

* `XlsxDataSource` — a `DataSource` that streams the rows of one worksheet,
  so a workbook can be inferred and imported like a CSV file (including in
  an isolate, via `loadFactsInIsolate`).
* `XlsxCubeExporter` — writes a `CubeLayout` (the expanded rows and
  columns exactly as shown) as a formatted worksheet: merged group headers
  in the "rotated L" shape, level shading, bold summaries, frozen headers,
  localized labels through `TesseraStrings`.

Pure Dart, no Flutter dependency — works in Flutter apps, on servers and in
command-line tools alike. Both directions live in one package because they
share the same OOXML machinery.

**Status: the reader (`XlsxDataSource`) works; the exporter is not implemented yet.**

```dart
import 'package:tessera_xlsx/tessera_xlsx.dart';

final source = XlsxDataSource.fromData(bytes, name: 'sales.xlsx');
final result = await loadFacts(source);

final xlsx = XlsxCubeExporter(strings: TesseraStrings.forLanguage('hu')!)
    .export(cube.layout);
```

## License

MIT — see [LICENSE](LICENSE). Author: László Zsolt Nagy.
