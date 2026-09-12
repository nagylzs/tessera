import 'aggregate.dart';
import 'cube_spec.dart';
import 'dimension_path.dart';

/// One visible row or column of a [CubeLayout].
abstract interface class HeaderEntry {
  DimensionPath get path;

  /// Nesting depth; `0` for the summary.
  int get depth;

  bool get isSummary;

  /// Formatted value of the deepest path entry (empty string for the empty
  /// group and the summary; the widget decides how to label those).
  String get label;

  /// Whether the entry has a level below it. `false` on the last level of
  /// the axis, so no expand icon is shown there.
  bool get isExpandable;

  bool get isExpanded;

  /// Number of facts in the group (after the cube's filter).
  int get factCount;
}

/// The materialised rows or columns of one axis: the groups actually visible
/// under the current [ExpansionState], in display order, each a
/// [HeaderEntry]. Groups without facts are omitted.
abstract interface class AxisLayout {
  CubeAxis get axis;

  List<HeaderEntry> get entries;

  int get length;

  /// Index of the entry with [path], or `-1`.
  int indexOf(DimensionPath path);
}

/// The facts and aggregates at one row/column intersection.
abstract interface class CubeCell {
  Coordinate get coordinate;

  /// Number of facts matched. `0` means the widget renders an empty cell.
  int get factCount;

  bool get isEmpty;

  /// Result of [aggregate], which must be one of the spec's aggregates.
  R? aggregate<R>(Aggregate<R> aggregate);

  Map<Aggregate, Object?> get aggregates;

  /// Indices into the [FactTable] of the facts behind this cell. Computed
  /// lazily; cells never store row lists.
  Iterable<int> get factRows;
}

/// The computed grid of a [Cube]: visible row and column entries plus a cell
/// for every intersection. Immutable; a new layout is produced whenever the
/// spec or the expansion state changes.
abstract interface class CubeLayout {
  CubeSpec get spec;

  AxisLayout get rows;

  AxisLayout get columns;

  CubeCell cellAt(int row, int column);

  /// Cell for a pair of paths, or `null` if either is not visible.
  CubeCell? cellFor(DimensionPath row, DimensionPath column);
}
