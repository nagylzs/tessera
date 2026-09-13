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
* Current cell: `CubeController.selection` / `currentCell`, `CellAddress`;
  `CubeView.selectable`, `focusNode`, `autofocus`, keyboard navigation and
  `CubeTheme.selectionColor`.
* `CubeView`: a data cell's level (for `CubeTheme.levelColor`) is the sum
  of its row and column depths, not the maximum.
