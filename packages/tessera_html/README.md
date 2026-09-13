# tessera_html

HTML export for the [tessera](../tessera) pivot-table engine.

`HtmlCubeExporter` writes a `CubeLayout` (the expanded rows and columns
exactly as shown) as a `<table>`: merged group headers in the "rotated L"
shape, one column per aggregate under each column entry, subtotals on the
group's own row, classes per cell kind and level, and a stylesheet from
the engine's `CubeExportTheme` — embedded in a `<style>`, inlined on the
cells (for e-mail), or left out so the page's CSS takes over. Labels and
numbers come from `TesseraStrings`, so the export is localized like the
widgets.

Pure Dart, no Flutter — servers, CLIs and apps alike.

```dart
import 'package:tessera_html/tessera_html.dart';

final html = HtmlCubeExporter(
  strings: TesseraStrings.forLanguage('hu')!,
  theme: CubeExportTheme.brand(primary: 0xFF00695C),
).export(cube.layout, title: 'Sales by region');
```

`export` returns the HTML as a `String` (a whole document, or a fragment
with `standalone: false`).

## Example

[`example/main.dart`](example/main.dart) reads `example/sales.csv`, builds
a region/country × year/quarter cube with every region expanded and writes
it as `sales_pivot.html`:

```
dart run example/main.dart [input.csv] [output.html]
```

## License

MIT — see [LICENSE](LICENSE). Author: László Zsolt Nagy.
