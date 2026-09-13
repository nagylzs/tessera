import 'package:flutter/foundation.dart';
import 'package:tessera/tessera.dart';

/// Holds the current [Cube] and notifies listeners whenever it is replaced.
///
/// The cube itself is immutable; the controller is the single mutable point
/// that widgets (and the example app's configuration UI) talk to.
/// A data cell named by its row and column groups rather than by indices,
/// so a selection survives sorting, expanding other groups and spec
/// changes; resolve it with [CubeController.currentCell]. [aggregate]
/// names the value column under the column group when a `CubeView` shows
/// several aggregates side by side (`null`: not specific to one).
final class CellAddress {
  const CellAddress({required this.row, required this.column, this.aggregate});

  final DimensionPath row;
  final DimensionPath column;
  final Aggregate? aggregate;

  @override
  bool operator ==(Object other) =>
      other is CellAddress &&
      other.row == row &&
      other.column == column &&
      other.aggregate == aggregate;

  @override
  int get hashCode => Object.hash(row, column, aggregate);

  @override
  String toString() =>
      'CellAddress($row × $column${aggregate == null ? '' : ', ${aggregate!.id}'})';
}

class CubeController extends ChangeNotifier {
  CubeController(Cube cube) : _cube = cube;

  Cube _cube;
  CellAddress? _selection;

  Cube get cube => _cube;

  set cube(Cube value) {
    if (identical(value, _cube)) return;
    _cube = value;
    notifyListeners();
  }

  /// The current cell of a `CubeView` (tapped or reached with the arrow
  /// keys), or `null`. Kept when the cell scrolls out of view or its group
  /// is collapsed — see [currentCell] for what is visible right now.
  CellAddress? get selection => _selection;

  set selection(CellAddress? value) {
    if (value == _selection) return;
    _selection = value;
    notifyListeners();
  }

  /// [selection] resolved against the current layout: the cell with its
  /// facts and aggregates, or `null` when nothing is selected or the
  /// selected groups are not visible (collapsed parent, dimension removed).
  CubeCell? get currentCell {
    final s = _selection;
    if (s == null) return null;
    final layout = _cube.layout;
    final i = layout.rows.indexOf(s.row);
    final j = layout.columns.indexOf(s.column);
    if (i < 0 || j < 0) return null;
    return layout.cellAt(i, j);
  }

  void toggleRow(DimensionPath path) => cube = _cube.toggleRow(path);

  void toggleColumn(DimensionPath path) => cube = _cube.toggleColumn(path);

  void updateSpec(CubeSpec spec) => cube = _cube.copyWith(spec: spec);

  /// See [Cube.expandRowLevel].
  void expandRowLevel(int level) => cube = _cube.expandRowLevel(level);

  /// See [Cube.collapseRowLevel].
  void collapseRowLevel(int level) => cube = _cube.collapseRowLevel(level);

  /// See [Cube.expandColumnLevel].
  void expandColumnLevel(int level) => cube = _cube.expandColumnLevel(level);

  /// See [Cube.collapseColumnLevel].
  void collapseColumnLevel(int level) =>
      cube = _cube.collapseColumnLevel(level);
}
