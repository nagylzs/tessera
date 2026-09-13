import 'package:flutter/foundation.dart';
import 'package:tessera/tessera.dart';

/// Holds the current [Cube] and notifies listeners whenever it is replaced.
///
/// The cube itself is immutable; the controller is the single mutable point
/// that widgets (and the example app's configuration UI) talk to.
class CubeController extends ChangeNotifier {
  CubeController(Cube cube) : _cube = cube;

  Cube _cube;

  Cube get cube => _cube;

  set cube(Cube value) {
    if (identical(value, _cube)) return;
    _cube = value;
    notifyListeners();
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
