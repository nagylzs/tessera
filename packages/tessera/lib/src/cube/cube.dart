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

  /// Expands every row group on [level] (`0` = the first row dimension),
  /// and the levels above it, so that the whole of level [level] + 1 is
  /// visible. Unlike [expandRowsToDepth] this keeps what is already
  /// expanded further down. A no-op on the last level.
  Cube expandRowLevel(int level) =>
      copyWith(rowExpansion: _expandLevel(spec.rows, rowExpansion, level));

  /// Collapses every row group on [level]; see [ExpansionState.collapseLevel].
  Cube collapseRowLevel(int level) =>
      copyWith(rowExpansion: rowExpansion.collapseLevel(level));

  /// Column-axis counterpart of [expandRowLevel].
  Cube expandColumnLevel(int level) => copyWith(
    columnExpansion: _expandLevel(spec.columns, columnExpansion, level),
  );

  /// Column-axis counterpart of [collapseRowLevel].
  Cube collapseColumnLevel(int level) =>
      copyWith(columnExpansion: columnExpansion.collapseLevel(level));

  /// Number of rows [expandRowLevel] would add — what a widget checks
  /// against its expansion limit before asking for confirmation. Costs one
  /// pass over the facts (no cells are computed); `0` when nothing changes.
  int rowsAddedByExpandingLevel(int level) =>
      _addedBy(spec.rows, rowExpansion, level, layout.rows.length);

  /// Column-axis counterpart of [rowsAddedByExpandingLevel].
  int columnsAddedByExpandingLevel(int level) =>
      _addedBy(spec.columns, columnExpansion, level, layout.columns.length);

  ExpansionState _expandLevel(CubeAxis axis, ExpansionState state, int level) =>
      expansionWithLevel(
        facts: facts,
        axis: axis,
        filter: spec.filter,
        level: level,
        state: state,
        cache: _cache,
      );

  int _addedBy(CubeAxis axis, ExpansionState state, int level, int current) {
    final next = _expandLevel(axis, state, level);
    if (next == state) return 0;
    final after = countEntries(
      facts: facts,
      axis: axis,
      filter: spec.filter,
      state: next,
      cache: _cache,
    );
    return after - current;
  }
}
