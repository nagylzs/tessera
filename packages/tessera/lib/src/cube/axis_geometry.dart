import 'cube_layout.dart';
import 'cube_spec.dart';
import 'dimension_path.dart';

/// One (possibly merged) cell of a header band.
///
/// Positions are in axis terms: `level` is the header row of a column band
/// (or the header column of a row band), `entry` is the index along the
/// axis. Areas never overlap and together tile the band.
final class HeaderArea {
  const HeaderArea({
    required this.path,
    required this.entryIndex,
    required this.levelStart,
    required this.levelSpan,
    required this.entryStart,
    required this.entrySpan,
    required this.isLabel,
  });

  /// The group this area belongs to; resolve it with
  /// [AxisLayout.entryFor], which also works when the group has no entry
  /// of its own.
  final DimensionPath path;

  /// Index of the group's own entry, or `-1` when it has none (an expanded
  /// group with a hidden subtotal).
  final int entryIndex;

  final int levelStart;
  final int levelSpan;
  final int entryStart;
  final int entrySpan;

  /// `true` for the cell that carries the group's label; `false` for the
  /// blank "leg" on the group's own row/column below its label.
  final bool isLabel;

  bool get isMerged => levelSpan > 1 || entrySpan > 1;

  @override
  bool operator ==(Object other) =>
      other is HeaderArea &&
      other.path == path &&
      other.entryIndex == entryIndex &&
      other.levelStart == levelStart &&
      other.levelSpan == levelSpan &&
      other.entryStart == entryStart &&
      other.entrySpan == entrySpan &&
      other.isLabel == isLabel;

  @override
  int get hashCode => Object.hash(
    path,
    entryIndex,
    levelStart,
    levelSpan,
    entryStart,
    entrySpan,
    isLabel,
  );

  @override
  String toString() =>
      'HeaderArea($path, entry $entryIndex, levels $levelStart+$levelSpan, '
      'entries $entryStart+$entrySpan${isLabel ? '' : ', leg'})';
}

/// Resolves the merged-cell structure of one axis's header band from its
/// [AxisLayout], in the "rotated L" style:
///
/// * an expanded group's label spans its whole subtree on its level; on
///   the group's own row (first, last or absent — [SubtotalPosition]) the
///   deeper levels form a blank leg;
/// * a collapsed group (or one on the last level) spans vertically from its
///   level to the last level;
/// * the summary spans all levels.
final class AxisGeometry {
  AxisGeometry(this.layout) {
    _build();
  }

  final AxisLayout layout;

  /// Number of header levels: the axis depth.
  int get levels => layout.axis.depth;

  int get length => layout.length;

  /// Per level and entry: the first index and the length of the run of
  /// entries belonging to the same group on that level (`0` span for the
  /// summary, which belongs to no group).
  late final List<List<int>> _runStart;
  late final List<List<int>> _runSpan;

  void _build() {
    final entries = layout.entries;
    _runStart = [
      for (var d = 0; d < levels; d++) List<int>.filled(entries.length, 0),
    ];
    _runSpan = [
      for (var d = 0; d < levels; d++) List<int>.filled(entries.length, 0),
    ];
    for (var d = 0; d < levels; d++) {
      var j = 0;
      while (j < entries.length) {
        final path = entries[j].path;
        if (path.length <= d) {
          j++; // summary, or above this level: no group here
          continue;
        }
        final key = _prefix(path, d + 1);
        var end = j + 1;
        while (end < entries.length &&
            entries[end].path.length > d &&
            _prefix(entries[end].path, d + 1) == key) {
          end++;
        }
        for (var k = j; k < end; k++) {
          _runStart[d][k] = j;
          _runSpan[d][k] = end - j;
        }
        j = end;
      }
    }
  }

  static DimensionPath _prefix(DimensionPath path, int length) =>
      path.length == length
      ? path
      : DimensionPath(path.entries.sublist(0, length));

  /// The area covering header position ([level], [entryIndex]).
  HeaderArea areaAt(int level, int entryIndex) {
    assert(level >= 0 && level < levels);
    final entries = layout.entries;
    final e = entries[entryIndex];
    if (e.depth == 0) {
      return HeaderArea(
        path: e.path,
        entryIndex: entryIndex,
        levelStart: 0,
        levelSpan: levels,
        entryStart: entryIndex,
        entrySpan: 1,
        isLabel: true,
      );
    }
    final ownLevel = e.depth - 1;
    if (level < ownLevel) {
      // an ancestor's label, spanning the ancestor's whole run
      final path = _prefix(e.path, level + 1);
      return HeaderArea(
        path: path,
        entryIndex: layout.indexOf(path),
        levelStart: level,
        levelSpan: 1,
        entryStart: _runStart[level][entryIndex],
        entrySpan: _runSpan[level][entryIndex],
        isLabel: true,
      );
    }
    final expanded = e.isExpanded && e.depth < levels;
    if (!expanded) {
      // a leaf (collapsed, or on the last level): one cell down to the
      // last level
      return HeaderArea(
        path: e.path,
        entryIndex: entryIndex,
        levelStart: ownLevel,
        levelSpan: levels - ownLevel,
        entryStart: entryIndex,
        entrySpan: 1,
        isLabel: true,
      );
    }
    if (level == ownLevel) {
      return HeaderArea(
        path: e.path,
        entryIndex: entryIndex,
        levelStart: level,
        levelSpan: 1,
        entryStart: _runStart[level][entryIndex],
        entrySpan: _runSpan[level][entryIndex],
        isLabel: true,
      );
    }
    // the group's own row, below its label: the leg
    return HeaderArea(
      path: e.path,
      entryIndex: entryIndex,
      levelStart: ownLevel + 1,
      levelSpan: levels - ownLevel - 1,
      entryStart: entryIndex,
      entrySpan: 1,
      isLabel: false,
    );
  }
}
