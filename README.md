# tessera

Analyze, group and aggregate tabular data in Dart and Flutter: a pivot-table
engine with expandable row/column hierarchies, and widgets to display and
edit the result.

This repository is a [pub workspace](https://dart.dev/tools/pub/workspaces)
with two packages:

| Package | Depends on | What it is |
|---|---|---|
| [`packages/tessera`](packages/tessera) | nothing | The engine: data sources, schema inference, fact table, cube, layout, localized strings. Pure Dart — servers, CLIs, isolates and the web. |
| [`packages/tessera_flutter`](packages/tessera_flutter) | `tessera`, Flutter | `CubeView`, the axis and aggregate editors, picker dialogs, `CubeTheme`, `TesseraLocalizations`. Its `example/` is the demo app. |
| [`packages/tessera_xlsx`](packages/tessera_xlsx) | `tessera`, `archive`, `xml` | `XlsxDataSource` (import a worksheet) and `XlsxCubeExporter` (write a cube as a formatted worksheet). Pure Dart. |
| [`packages/tessera_ods`](packages/tessera_ods) | `tessera`, `archive`, `xml` | `OdsDataSource` and `OdsCubeExporter`: the same for OpenDocument spreadsheets (LibreOffice Calc). Pure Dart. |
| [`packages/tessera_html`](packages/tessera_html) | `tessera` | `HtmlCubeExporter`: a cube as an HTML table with merged headers and a stylesheet from `CubeExportTheme`. Pure Dart. |

Exporters (xlsx, pdf, html) are planned as further packages that render a
`CubeLayout` without Flutter.

> **Status: early development.** Nothing is published to pub.dev yet.

## Development

```bash
dart pub get                                  # resolves the whole workspace
dart analyze                                  # all packages
(cd packages/tessera && dart test)            # engine
(cd packages/tessera_flutter && flutter test) # widgets
(cd packages/tessera_flutter/example && flutter run)
dart format packages
```

## Author

László Zsolt Nagy <nagylzs@gmail.com>

## License

MIT — see [LICENSE](LICENSE).
