## 0.0.1

* Initial release: `CubeView`, `CubeController`, `AxisEditor`,
  `AggregateEditor`, the dimension and aggregate picker dialogs,
  `CubeTheme` and `TesseraLocalizations`.
* `CubeView`: a menu on every dimension title (`▾` button, long press or
  secondary click) with the sort direction and "expand all" / "collapse
  all" for that level; `confirmLevelExpansion` guards large ones.
  `CubeController.expandRowLevel` and friends.
