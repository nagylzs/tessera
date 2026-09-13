import '../facts/dimension.dart';
import '../facts/fact_table.dart';
import 'aggregate.dart';
import 'cube_spec.dart';
import 'dimension_path.dart';

/// One visible row or column of a [CubeLayout].
abstract interface class HeaderEntry {
  DimensionPath get path;

  /// Nesting depth; `0` for the summary.
  int get depth;

  bool get isSummary;

  /// Dimension of the deepest path entry; `null` for the summary.
  Dimension? get dimension;

  /// Value of the deepest path entry; `null` for the empty group and for the
  /// summary (tell them apart with [isSummary]).
  Object? get value;

  /// Formatted value of the deepest path entry (empty string for the empty
  /// group and the summary; the widget decides how to label those).
  String get label;

  /// Whether the entry has a level below it. `false` on the last level of
  /// the axis, so no expand icon is shown there.
  bool get isExpandable;

  bool get isExpanded;

  /// Number of facts in the group (after the cube's filter).
  int get factCount;

  /// Number of groups one level down — what expanding this entry would add
  /// to the axis. `0` on the last level. Computed on demand for collapsed
  /// entries, so a widget can ask before an expensive expansion.
  int get childCount;
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

  /// The group at [path]: its entry when it has one, or — for an expanded
  /// group whose subtotal is hidden ([SubtotalPosition.hidden]) — an entry
  /// that is not in [entries] but still carries the label, expansion state
  /// and fact count its header area needs. `null` for a group the layout
  /// does not have.
  HeaderEntry? entryFor(DimensionPath path);

  /// Number of other entries in the subtree of the entry at [index] — the
  /// rows/columns its label spans besides its own. `0` for leaves and for
  /// the summary.
  int descendantCount(int index);
}

/// The facts and aggregates at one row/column intersection.
abstract interface class CubeCell {
  Coordinate get coordinate;

  /// Number of facts matched. `0` means the widget renders an empty cell.
  int get factCount;

  bool get isEmpty;

  /// Result of [aggregate], which must be one of the spec's aggregates
  /// (otherwise [ArgumentError]).
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

  /// The facts the layout was computed from.
  FactTable get facts;

  AxisLayout get rows;

  AxisLayout get columns;

  CubeCell cellAt(int row, int column);

  /// Cell for a pair of paths, or `null` if either is not visible.
  CubeCell? cellFor(DimensionPath row, DimensionPath column);
}
