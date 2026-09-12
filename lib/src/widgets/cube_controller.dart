import 'package:flutter/foundation.dart';

import '../cube/cube.dart';
import '../cube/cube_spec.dart';
import '../cube/dimension_path.dart';

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
}
