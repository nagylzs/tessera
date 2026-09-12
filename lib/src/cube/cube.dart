import '../facts/fact_table.dart';
import 'cube_engine.dart';
import 'cube_layout.dart';
import 'cube_spec.dart';
import 'dimension_path.dart';
import 'expansion_state.dart';

/// A [FactTable] viewed through a [CubeSpec] and an expansion state for each
/// axis.
///
/// The cube is an immutable value: changing anything returns a new cube.
/// Its [layout] is computed on first access and cached, and cubes derived
/// with [copyWith] share the dictionary-encoded dimension values and the
/// filtered row set, so toggling a group costs one pass over the facts and
/// nothing more.
///
/// A cube contains no Flutter types. The widgets layer wraps it in a
/// `CubeController` to drive rebuilds.
final class Cube {
  Cube({
    required FactTable facts,
    required CubeSpec spec,
    ExpansionState? rowExpansion,
    ExpansionState? columnExpansion,
  }) : this._(
         facts,
         spec,
         rowExpansion ?? ExpansionState.initial(),
         columnExpansion ?? ExpansionState.initial(),
         CubeCache(),
       );

  Cube._(
    this.facts,
    this.spec,
    this.rowExpansion,
    this.columnExpansion,
    this._cache,
  );

  final FactTable facts;
  final CubeSpec spec;
  final ExpansionState rowExpansion;
  final ExpansionState columnExpansion;
  final CubeCache _cache;

  late final CubeLayout layout = computeLayout(
    facts: facts,
    spec: spec,
    rowExpansion: rowExpansion,
    columnExpansion: columnExpansion,
    cache: _cache,
  );

  Cube copyWith({
    CubeSpec? spec,
    ExpansionState? rowExpansion,
    ExpansionState? columnExpansion,
  }) => Cube._(
    facts,
    spec ?? this.spec,
    rowExpansion ?? this.rowExpansion,
    columnExpansion ?? this.columnExpansion,
    _cache,
  );

  Cube toggleRow(DimensionPath path) =>
      copyWith(rowExpansion: rowExpansion.toggle(path));

  Cube toggleColumn(DimensionPath path) =>
      copyWith(columnExpansion: columnExpansion.toggle(path));

  /// Expands every row group down to [depth] levels (`0` collapses to the
  /// summary only, `1` is the initial state). Only groups that have facts
  /// (after the filter) are expanded.
  Cube expandRowsToDepth(int depth) => copyWith(
    rowExpansion: expansionToDepth(
      facts: facts,
      axis: spec.rows,
      filter: spec.filter,
      depth: depth,
      cache: _cache,
    ),
  );

  Cube expandColumnsToDepth(int depth) => copyWith(
    columnExpansion: expansionToDepth(
      facts: facts,
      axis: spec.columns,
      filter: spec.filter,
      depth: depth,
      cache: _cache,
    ),
  );
}
