# tessera_pdf

PDF export for the [tessera](../tessera) pivot-table engine.

`PdfCubeExporter` writes a `CubeLayout` (the expanded rows and columns
exactly as shown) as a paginated document: merged group headers in the
"rotated L" shape, one column per aggregate under each column entry,
subtotals on the group's own row, fills and fonts from the engine's
`CubeExportTheme`. Pages break only on grid lines; the header band and
the row header repeat on every page like a spreadsheet's print titles.
The grid is scaled to fit the page width down to a minimum scale, and
tiled across pages beyond that (`fitToWidth`, `minScale`). A minimal
page header and footer take three texts each with `{title}`, `{page}`,
`{pages}` and `{date}` placeholders. Labels and numbers come from
`TesseraStrings`, so the export is localized like the widgets.

Fonts: pass TrueType files as `PdfFonts` — they are embedded (subsetted)
and their metrics size the columns exactly. Without them the built-in
Helvetica is used, which covers Western European characters only.

Pure Dart on [`package:pdf`](https://pub.dev/packages/pdf), no Flutter
— servers, CLIs and apps alike.

```dart
import 'package:tessera_pdf/tessera_pdf.dart';

final bytes = await PdfCubeExporter(
  strings: TesseraStrings.forLanguage('hu')!,
  theme: CubeExportTheme.brand(primary: 0xFF00695C),
  fonts: PdfFonts(regular: notoRegular, bold: notoBold),
  pageSetup: const PageSetup(size: PageSize.a4, orientation: PageOrientation.landscape),
  footer: const PdfPageText(left: '{date}', right: '{page} / {pages}'),
).export(cube.layout, title: 'Sales by region');
```

`export` is asynchronous and returns the PDF as a `Future<Uint8List>`
(font embedding in `package:pdf` is async); the other exporters are
synchronous.

## Example

[`example/main.dart`](example/main.dart) reads `example/sales.csv`, builds
a region/country × year/quarter cube with every region expanded and writes
it as `sales_pivot.pdf`, using Noto Sans from `/usr/share/fonts/noto`
when present:

```
dart run example/main.dart [input.csv] [output.pdf] [font directory]
```

## License

MIT — see [LICENSE](LICENSE). Author: László Zsolt Nagy.
