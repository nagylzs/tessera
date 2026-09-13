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
| [`packages/tessera_svg`](packages/tessera_svg) | `tessera` | `SvgCubeExporter`: a cube as a scalable image, content-sized columns, themed with `CubeExportTheme`. Pure Dart. |
| [`packages/tessera_pdf`](packages/tessera_pdf) | `tessera`, `pdf` | `PdfCubeExporter`: paginated pages with repeated headers, fit to width or tiling, embedded fonts, page header/footer. Pure Dart. |

Every exporter renders a `CubeLayout` without Flutter; further formats
can be added the same way.

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
