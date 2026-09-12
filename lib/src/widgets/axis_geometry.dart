import '../cube/cube_layout.dart';

/// One (possibly merged) cell of a header band.
///
/// Positions are in axis terms: `level` is the header row of a column band
/// (or the header column of a row band), `entry` is the index along the
/// axis. Areas never overlap and together tile the band.
final class HeaderArea {
  const HeaderArea({
    required this.entryIndex,
    required this.levelStart,
    required this.levelSpan,
    required this.entryStart,
    required this.entrySpan,
    required this.isLabel,
  });

  /// The entry this area belongs to.
  final int entryIndex;

  final int levelStart;
  final int levelSpan;
  final int entryStart;
  final int entrySpan;

  /// `true` for the cell that carries the entry's label; `false` for the
  /// blank "leg" below an expanded entry's label in its own column.
  final bool isLabel;

  bool get isMerged => levelSpan > 1 || entrySpan > 1;

  @override
  bool operator ==(Object other) =>
      other is HeaderArea &&
      other.entryIndex == entryIndex &&
      other.levelStart == levelStart &&
      other.levelSpan == levelSpan &&
      other.entryStart == entryStart &&
      other.entrySpan == entrySpan &&
      other.isLabel == isLabel;

  @override
  int get hashCode => Object.hash(
    entryIndex,
    levelStart,
    levelSpan,
    entryStart,
    entrySpan,
    isLabel,
  );

  @override
  String toString() =>
      'HeaderArea(entry $entryIndex, levels $levelStart+$levelSpan, '
      'entries $entryStart+$entrySpan${isLabel ? '' : ', leg'})';
}

/// Resolves the merged-cell structure of one axis's header band from its
/// [AxisLayout], in the "rotated L" style:
///
/// * an expanded entry's label spans its own column plus all descendants on
///   its level; below the label, its own column is a blank leg down to the
///   last level;
/// * a collapsed entry (or one on the last level) spans vertically from its
///   level to the last level;
/// * the summary spans all levels.
final class AxisGeometry {
  AxisGeometry(this.layout) : _ancestors = _computeAncestors(layout);

  final AxisLayout layout;

  /// `_ancestors[j][d - 1]` is the index of entry `j`'s ancestor at depth
  /// `d` (itself at its own depth). The summary is never an ancestor.
  final List<List<int>> _ancestors;

  /// Number of header levels: the axis depth.
  int get levels => layout.axis.depth;

  int get length => layout.length;

  static List<List<int>> _computeAncestors(AxisLayout layout) {
    final result = <List<int>>[];
    final stack = <int>[];
    for (var j = 0; j < layout.length; j++) {
      final depth = layout.entries[j].depth;
      while (stack.isNotEmpty && stack.length >= depth) {
        stack.removeLast();
      }
      if (depth > 0) stack.add(j);
      result.add(List.unmodifiable(stack));
    }
    return result;
  }

  /// The area covering header position ([level], [entryIndex]).
  HeaderArea areaAt(int level, int entryIndex) {
    assert(level >= 0 && level < levels);
    final entries = layout.entries;
    final e = entries[entryIndex];
    if (e.depth == 0) {
      return HeaderArea(
        entryIndex: entryIndex,
        levelStart: 0,
        levelSpan: levels,
        entryStart: entryIndex,
        entrySpan: 1,
        isLabel: true,
      );
    }
    final owner = level <= e.depth - 1
        ? _ancestors[entryIndex][level]
        : entryIndex;
    final o = entries[owner];
    final descendants = layout.descendantCount(owner);
    final ownerLevel = o.depth - 1;
    if (descendants == 0) {
      return HeaderArea(
        entryIndex: owner,
        levelStart: ownerLevel,
        levelSpan: levels - ownerLevel,
        entryStart: owner,
        entrySpan: 1,
        isLabel: true,
      );
    }
    if (level == ownerLevel) {
      return HeaderArea(
        entryIndex: owner,
        levelStart: level,
        levelSpan: 1,
        entryStart: owner,
        entrySpan: descendants + 1,
        isLabel: true,
      );
    }
    return HeaderArea(
      entryIndex: owner,
      levelStart: ownerLevel + 1,
      levelSpan: levels - ownerLevel - 1,
      entryStart: owner,
      entrySpan: 1,
      isLabel: false,
    );
  }
}
