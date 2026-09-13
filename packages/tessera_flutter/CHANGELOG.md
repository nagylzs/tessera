## 0.0.1

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
