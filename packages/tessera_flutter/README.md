# tessera_flutter

Flutter widgets for the [`tessera`](https://pub.dev/packages/tessera)
pivot-table engine: an expandable cube grid, drag-and-drop axis and
aggregate editors, picker dialogs, and localizations for fourteen
languages.

> **Status: early development.** Everything works end to end and is covered
> by widget tests, but the API is still moving and nothing is published to
> pub.dev yet.

This package re-exports `package:tessera/tessera.dart`, so a single import
gives you both the engine and the widgets. Read the engine's README for the
concepts (data sources, schema inference, fact tables, cube specs).

## Widgets

| Widget | Role |
|---|---|
| `CubeController` | The single mutable object: holds the current `Cube`, applies expand/collapse, sort and spec changes, notifies listeners. |
| `CubeView` | The grid. Built on `TableView` from `two_dimensional_scrollables`: lazy cells, pinned and merged group headers, expand/collapse icons, sort by tapping headers. |
| `AxisEditor` | Chips for the dimensions of one axis; drag-and-drop within and between axes, delete, `+` opens `showDimensionPicker`. |
| `AggregateEditor` | Chips for the aggregates; `+` opens `showAggregatePicker`; `selected`/`onSelected` let the app choose what `CubeView` shows. |
| `CubeTheme` | Colours, sizes and text styles; defaults to the ambient Material theme. |
| `TesseraLocalizations` | `delegate`, `supportedLocales` and `of(context)` for the engine's `TesseraStrings`. |

## Usage

```dart
import 'package:tessera_flutter/tessera_flutter.dart';

final controller = CubeController(Cube(facts: facts, spec: spec));

Column(
  children: [
    AxisEditor(controller: controller, side: AxisSide.rows),
    AxisEditor(controller: controller, side: AxisSide.columns),
    AggregateEditor(controller: controller),
    Expanded(
      child: CubeView(
        controller: controller,
        aggregate: Aggregate.sum(const Measure('total')),
        formatCell: (cell, value) => myNumberFormat.format(value),
      ),
    ),
  ],
)
```

Expand and collapse groups with the `+`/`−` icons; tap a dimension name to
sort that level by value, or the aggregate name under a column to sort the
rows by that column. `expansionLimit` + `confirmExpansion` ask before an
expansion would add too many rows or columns.

### Localization

```dart
MaterialApp(
  localizationsDelegates: const [
    TesseraLocalizations.delegate,
    ...GlobalMaterialLocalizations.delegates,
  ],
  supportedLocales: TesseraLocalizations.supportedLocales,
)
```

Without a delegate the widgets fall back to English. To force a language
(or supply your own `TesseraStrings` subclass), wrap the app in a
`TesseraLocalizationsScope`.

## Example app

`example/` is one Flutter app with a launcher page listing several examples
(`example/lib/examples.dart`). *Simple pivot* (`example/lib/simple/`) loads
`example/assets/sales.csv` (1 000 generated sales rows with deliberately
missing values, hierarchical dimensions and orphan values — see
`example/tool/gen_sales_csv.dart`) and lets you configure everything
interactively: the inferred schema (include, type, label, date format,
number syntax per column), the axes (drag-and-drop), the aggregates, the
language, and the cube itself. *Public datasets* (`example/lib/datasets/`)
downloads real-world CSV files of up to ~70 MB through a custom
`HttpCsvDataSource` (`example/lib/common/http_csv_data_source.dart`) — a
worked example of implementing `DataSource`, with early-cancelled prefix
reads, a download cache and `Content-Length`-based progress.

```bash
cd example && flutter run
```

## Contributing

Issues and pull requests are welcome at
<https://github.com/nagylzs/tessera>. Run `flutter analyze` and
`flutter test` before submitting.

## Author

László Zsolt Nagy <nagylzs@gmail.com>

## License

MIT — see [LICENSE](LICENSE).
