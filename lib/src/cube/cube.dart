import '../facts/fact_table.dart';
import 'cube_layout.dart';
import 'cube_spec.dart';
import 'dimension_path.dart';
import 'expansion_state.dart';

/// A [FactTable] viewed through a [CubeSpec] and an expansion state for each
/// axis.
///
/// The cube is an immutable value: changing anything returns a new cube.
/// Its [layout] is computed on first access and cached, and cubes derived
/// with [copyWith] reuse whatever intermediate results are still valid, so
/// toggling a group does not rescan the facts.
///
/// A cube contains no Flutter types. The widgets layer wraps it in a
/// `CubeController` to drive rebuilds.
final class Cube {
  Cube({
    required this.facts,
    required this.spec,
    ExpansionState? rowExpansion,
    ExpansionState? columnExpansion,
  }) : rowExpansion = rowExpansion ?? ExpansionState.initial(),
       columnExpansion = columnExpansion ?? ExpansionState.initial();

  final FactTable facts;
  final CubeSpec spec;
  final ExpansionState rowExpansion;
  final ExpansionState columnExpansion;

  late final CubeLayout layout = _computeLayout();

  CubeLayout _computeLayout() => throw UnimplementedError();

  Cube copyWith({
    CubeSpec? spec,
    ExpansionState? rowExpansion,
    ExpansionState? columnExpansion,
  }) => Cube(
    facts: facts,
    spec: spec ?? this.spec,
    rowExpansion: rowExpansion ?? this.rowExpansion,
    columnExpansion: columnExpansion ?? this.columnExpansion,
  );

  Cube toggleRow(DimensionPath path) =>
      copyWith(rowExpansion: rowExpansion.toggle(path));

  Cube toggleColumn(DimensionPath path) =>
      copyWith(columnExpansion: columnExpansion.toggle(path));

  /// Expands every row group down to [depth] levels (`0` collapses to the
  /// summary only). Requires the facts, since only groups that exist can be
  /// expanded.
  Cube expandRowsToDepth(int depth) => throw UnimplementedError();

  Cube expandColumnsToDepth(int depth) => throw UnimplementedError();
}
