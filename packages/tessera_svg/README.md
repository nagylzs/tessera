# tessera_svg

SVG export for the [tessera](../tessera) pivot-table engine.

`SvgCubeExporter` draws a `CubeLayout` (the expanded rows and columns
exactly as shown) as one scalable image: merged group headers in the
"rotated L" shape, one column per aggregate under each column entry,
subtotals on the group's own row, fills and fonts from the engine's
`CubeExportTheme` (brand, gradient and hue-level themes alike). Labels
and numbers come from `TesseraStrings`, so the export is localized like
the widgets. Columns are sized to their content by the engine's
`GridMetrics`; pure Dart cannot measure text, so widths are estimated
from the font and every text is clipped to its cell — pass `measureText`
(a `TextPainter` in a Flutter app) for exact widths.

Pure Dart, no Flutter — servers, CLIs and apps alike. Embeds in web
pages and documents, prints crisply at any size.

```dart
import 'package:tessera_svg/tessera_svg.dart';

final svg = SvgCubeExporter(
  strings: TesseraStrings.forLanguage('hu')!,
  theme: CubeExportTheme.brand(primary: 0xFF00695C),
).export(cube.layout, title: 'Sales by region');
```

`export` returns the SVG as a `String`.

> **User guide:** [github.com/nagylzs/tessera/docs](https://github.com/nagylzs/tessera/blob/main/docs/README.md) — data sources, schema, cubes, aggregates, filters, the expression language, widgets, theming, export, localization, saving, large data.

## Example

[`example/main.dart`](example/main.dart) reads `example/sales.csv`, builds
a region/country × year/quarter cube with every region expanded and writes
it as `sales_pivot.svg`:

```
dart run example/main.dart [input.csv] [output.svg]
```

## License

MIT — see [LICENSE](LICENSE). Author: László Zsolt Nagy.
