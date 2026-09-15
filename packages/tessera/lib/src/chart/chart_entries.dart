import '../cube/cube_layout.dart';
import '../cube/dimension_path.dart';

/// Which entries of an [AxisLayout] a chart helper turns into categories,
/// series or points.
///
/// A pivot axis is a tree: an expanded group's entry is its subtotal and its
/// children follow. Charting every entry would count facts twice (Europe
/// and then Germany, France …), so the default, [leaves], takes the visible
/// leaves only — every fact appears in at most one of them. [level] takes
/// one nesting level instead (the regions, whether expanded or not);
/// [paths] names the entries; [all] takes the axis verbatim, summary
/// included, for a chart that mirrors the table.
sealed class ChartEntries {
  const ChartEntries();

  /// The visible leaves: entries that are neither expanded nor the summary.
  /// On an axis without dimensions — only the summary exists — that single
  /// entry.
  static const ChartEntries leaves = _Leaves();

  /// Every entry, summary included.
  static const ChartEntries all = _All();

  /// The entries at one nesting depth (`1` = the axis' first dimension),
  /// expanded or not. Entries below a collapsed group are not visible and
  /// therefore not included.
  const factory ChartEntries.level(int depth) = _Level;

  /// The entries with these paths, in this order; paths the layout does not
  /// show are skipped.
  const factory ChartEntries.paths(List<DimensionPath> paths) = _Paths;

  /// The selected entries of [axis], in display order.
  List<HeaderEntry> select(AxisLayout axis);
}

final class _Leaves extends ChartEntries {
  const _Leaves();

  @override
  List<HeaderEntry> select(AxisLayout axis) {
    if (axis.axis.isEmpty) return axis.entries;
    return [
      for (final e in axis.entries)
        if (!e.isSummary && !e.isExpanded) e,
    ];
  }
}

final class _All extends ChartEntries {
  const _All();

  @override
  List<HeaderEntry> select(AxisLayout axis) => axis.entries;
}

final class _Level extends ChartEntries {
  const _Level(this.depth);

  final int depth;

  @override
  List<HeaderEntry> select(AxisLayout axis) => [
    for (final e in axis.entries)
      if (e.depth == depth) e,
  ];
}

final class _Paths extends ChartEntries {
  const _Paths(this.paths);

  final List<DimensionPath> paths;

  @override
  List<HeaderEntry> select(AxisLayout axis) => [
    for (final p in paths)
      if (axis.indexOf(p) case final i when i >= 0) axis.entries[i],
  ];
}
