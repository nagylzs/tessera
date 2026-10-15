## Unreleased

* The dimension picker, the aggregate picker and the filter editor's
  value list are usable on a phone in landscape. On a screen shorter
  than 480 dp they open full screen — title and search field (or the
  function dropdown) in the bar, the list below — and no longer open
  the keyboard by themselves, which left the list no room; dragging
  the list closes the keyboard. Taller screens keep the dialogs as
  they were.

## 0.2.2

* The menus of `CubeView` (dimension titles), `AxisEditor` (the
  caption), `AggregateEditor` (the chips' "Show values as") and the
  filter editor close on the system back (Android's back button or
  gesture, the browser's back) instead of leaving it to pop the page,
  sheet or dialog under them. A page with `PopScope(canPop: false)`
  still claims that back first; let it through with `canPop:
  ModalRoute.of(context)!.willHandlePopInternally`.
* Example app: the export menu's "Facts as a table" submenu writes the
  facts passing the cube's filter as a filterable .xlsx or .ods sheet,
  CSV or JSON Lines (`ExportTable.ofFacts` and the table exporters).

## 0.2.1

* Example app: JSON and JSON Lines in the export menu.
* Example app: a "Charts" page — a live chart beside the grid (below it
  on a tall screen) drawn with `fl_chart` from the engine's `ChartData`
  / `ScatterData`: bar, stacked, line (time / numeric / categorical X
  axis from the typed category values), pie and scatter, from the layout
  as displayed, from the facts, or from the current cell's drill-down
  (dimensions the cell pins are disabled); per-fact scatter of the cell's
  rows. `CubeWorkbench.companion` places a pane next to the view;
  `--dart-define=EXAMPLE=<title>` opens an example directly.

## 0.2.0

Requires `tessera` 0.2.0 (the expression language, statistical and
layout-relative aggregates, structured filters, JSON and snapshots).

* `FilterEditor`, `FilterEditorDialog`, `showFilterEditor` and
  `FilterEditorResult` / `FilterEditorValue`: a filter editor with
  all-of / any-of / not groups, typed condition rows (including "is one
  of" from the column's distinct values and a date picker), expression
  rows with live validation and read-only rows for filters without an
  editable form.
* `ExpressionField` (with `ExpressionTextController`, which underlines the
  error range): an expression text field validated on every keystroke,
  the message in the current language; no message while the field is
  still empty.
* Aggregate picker: a "Formula" function for cell formulas
  (`Aggregate.expression`) and an "Expression…" entry under every measure
  function for calculated measures (`Measure.expression`), each with a
  label field; the new statistical kinds; `AggregatePickerDialog.facts` /
  `functions`, `showAggregatePicker(functions:)`,
  `AggregateEditor.functions`. The function dropdown expands to the
  dialog width and ellipsizes long names.
* `AggregateEditor`: a long press or secondary click on a chip opens
  "Show values as" with the `ValueDisplay` choices; the wrapped aggregate
  replaces the chip in the spec, in sorts and in the selection.
* `AxisSide` now comes from the engine (re-exported, no import change).
* Example app: a "Filter…" action, the active filter shown under the
  grid, "records" instead of "facts" in the status line.

## 0.1.1

* README: the status note no longer says the package is unpublished.

## 0.1.0

* `CubeView` shows several aggregates side by side — one value column per
  aggregate under each column entry, the same layout the exporters write.
  `aggregate` became `aggregates` (`null` = all of the spec's);
  `AggregateEditor.selected` is a set with `onSelectedChanged`;
  `CellAddress.aggregate` names the value column of the current cell.

* Initial release: `CubeView`, `CubeController`, `AxisEditor`,
  `AggregateEditor`, the dimension and aggregate picker dialogs,
  `CubeTheme` and `TesseraLocalizations`.
* `CubeView`: a menu on every dimension title (`▾` button, long press or
  secondary click) with the sort direction and "expand all" / "collapse
  all" for that level; `confirmLevelExpansion` guards large ones.
  `CubeController.expandRowLevel` and friends.
* `CubeView`: sorting by a column's aggregate sets the first row level and
  lets the others inherit; a deeper level's title cycles through the
  opposite direction, the same direction and inheriting, and its menu has
  "same order as the level above".
* Column widths are measured with the theme's text styles merged onto the
  ambient `DefaultTextStyle`, as `Text` renders them, so styles without a
  font family or size no longer produce truncated columns.
* `AxisEditor`: the caption ("Rows" / "Columns") opens a menu with the
  axis's summary position (end / start / hidden) and subtotal position
  (above / below / hidden).
* `CubeTheme.headerIconColor`: header icons default to the header text
  colour instead of the ambient icon colour.
* Current cell: `CubeController.selection` / `currentCell`, `CellAddress`;
  `CubeView.selectable`, `focusNode`, `autofocus`, keyboard navigation and
  `CubeTheme.selectionColor`.
* `CubeView`: a data cell's level (for `CubeTheme.levelColor`) is the sum
  of its row and column depths, not the maximum.
* `CubeTheme.levelColor` takes a `CellLevel` (row and column depth
  separately, `depth` = their sum); `headerLevelColor` colours headers
  per level (`HeaderLevel`); `hueLevels: HueLevels()` colours levels by
  hue alone — cells by their row level, headers the same hue with more
  chroma, the first hue from the app's primary colour, light and dark
  defaults from the brightness, summaries neutral.
