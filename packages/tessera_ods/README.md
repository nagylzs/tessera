# tessera_ods

OpenDocument Spreadsheet (`.ods` — LibreOffice Calc, Collabora, …)
support for the [tessera](../tessera) pivot-table engine:

* `OdsDataSource` — a `DataSource` that streams the rows of one sheet, so a
  document can be inferred and imported like a CSV file (including in an
  isolate, via `loadFactsInIsolate`).
* `OdsCubeExporter` — writes a `CubeLayout` (the expanded rows and columns
  exactly as shown) as a formatted sheet: merged group headers in the
  "rotated L" shape, level shading, bold summaries, frozen headers,
  localized labels through `TesseraStrings`, looks from the engine's
  `CubeExportTheme` (shared with `tessera_xlsx`).

Pure Dart, no Flutter dependency — works in Flutter apps, on servers and in
command-line tools alike.

```dart
import 'package:tessera_ods/tessera_ods.dart';

final source = OdsDataSource.fromData(bytes, name: 'sales.ods');
final result = await loadFacts(source);

final ods = OdsCubeExporter(
  strings: TesseraStrings.forLanguage('hu')!,
  theme: CubeExportTheme.brand(primary: 0xFF00695C),
).export(cube.layout);
```

## Example

[`example/main.dart`](example/main.dart) does the whole round trip from
the command line — read `example/sales.ods`, infer and import, build a
region/country × year/quarter cube with every region expanded, write it
as `sales_pivot.ods`:

```
dart run example/main.dart [input.ods] [output.ods]
```

## License

MIT — see [LICENSE](LICENSE). Author: László Zsolt Nagy.
