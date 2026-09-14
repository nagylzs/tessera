# tessera_flutter

![CubeView: regions and countries against years and quarters, with a group and a year expanded](https://raw.githubusercontent.com/nagylzs/tessera/main/packages/tessera_flutter/doc/cube_view.png)

Flutter widgets for the [`tessera`](https://pub.dev/packages/tessera)
pivot-table engine: an expandable cube grid, drag-and-drop axis and
aggregate editors, picker dialogs, and localizations for fourteen
languages.

> **Status: 0.1.x.** Everything works end to end and is covered by widget
> tests; the API may still change before 1.0 (see the CHANGELOG).

This package re-exports `package:tessera/tessera.dart`, so a single import
gives you both the engine and the widgets. Read the engine's README for the
concepts (data sources, schema inference, fact tables, cube specs).

## Widgets

| Widget | Role |
|---|---|
| `CubeController` | The single mutable object: holds the current `Cube`, applies expand/collapse, sort and spec changes, notifies listeners. |
| `CubeView` | The grid. Built on `TableView` from `two_dimensional_scrollables`: lazy cells, pinned and merged group headers, expand/collapse icons, sort by tapping headers. |
| `AxisEditor` | Chips for the dimensions of one axis; drag-and-drop within and between axes, delete, `+` opens `showDimensionPicker`. |
| `AggregateEditor` | Chips for the aggregates; `+` opens `showAggregatePicker`, which besides the built-in functions offers a cell formula (`sum(total) / count`) and, under every measure function, a calculated measure (`quantity * unit_price`), both validated as the user types; a long press or right click on a chip opens "Show values as" (percent of a total, difference from the previous group, running total, rank). `selected`/`onSelectedChanged` let the app choose which aggregates `CubeView` shows. |
| `ExpressionField` | A text field for an expression, validated on every keystroke in a given scope with the error range underlined (`ExpressionTextController`) and the message in the current language; what the filter editor and the aggregate picker use. |
| `FilterEditor` / `showFilterEditor` | Edits the cube's filter as a tree: "all of" / "any of" groups with a "not" toggle, condition rows (column, operator, value — typed fields, a date picker, "is one of" with the column's distinct values) and expression rows validated as the user types with the error underlined and explained in the current language; filters the editor cannot represent (a `PredicateFilter`) are shown read-only. Returns a `FilterEditorResult`. |
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
        // one value column per aggregate under each column entry;
        // omit to show every aggregate of the spec
        aggregates: [Aggregate.sum(const Measure('total')), Aggregate.count],
        formatCell: (cell, value) => myNumberFormat.format(value),
      ),
    ),
  ],
)
```

Expand and collapse groups with the `+`/`−` icons; tap a dimension name to
sort that level by value, or an aggregate name under a column to sort the
rows by that value column. A level without a sort of its own follows the level
above (`AxisDimension.sort == null`), so a deeper level's name cycles
through the opposite direction, the same direction, and inheriting again.
Every dimension name also has a menu (its `▾` button, a long press, or a
secondary click) with the sort direction, "same order as the level above",
and "expand all" / "collapse all" for that level. `expansionLimit` with
`confirmExpansion` / `confirmLevelExpansion` ask before an expansion would
add too many rows or columns.

Tapping a data cell makes it the *current cell*: it is outlined, its row
and column headers are tinted, and `controller.selection` holds its
`CellAddress` (row and column paths, so it survives sorting and expanding
other groups). `controller.currentCell` resolves it against the current
layout — the `CubeCell` with its facts and aggregates, or `null` when the
cell is not visible — which is what an app charts or drills into. The view
takes focus on tap; the arrow keys, Home/End (first/last column, with
Ctrl first/last row) and Page Up/Down (on the number block too) move the
current cell (scrolled into view), Enter or Space toggles its row group and
Escape clears it. `selectable: false` turns this off; `focusNode` and
`autofocus` work as on a `TextField`. `CubeTheme.selectionColor` is the
outline colour.

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
