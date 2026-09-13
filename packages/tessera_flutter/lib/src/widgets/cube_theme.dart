import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tessera/tessera.dart';

/// Where a data cell sits in the two hierarchies, for [LevelColor].
///
/// [row] is the row group's depth from `0` (the first row dimension),
/// [column] the column group's depth likewise; [rowLevels] and
/// [columnLevels] are the dimension counts of the axes. [depth] adds the
/// two, the way a gradient shades deeper cells, [maxDepth] is the deepest
/// possible cell (every level of both axes open).
final class CellLevel {
  const CellLevel({
    required this.row,
    required this.column,
    required this.rowLevels,
    required this.columnLevels,
  });

  final int row;
  final int column;
  final int rowLevels;
  final int columnLevels;

  /// Row depth + column depth, from `0`.
  int get depth => row + column;

  /// The largest [depth] the cube can show.
  int get maxDepth =>
      math.max(rowLevels - 1, 0) + math.max(columnLevels - 1, 0);

  @override
  bool operator ==(Object other) =>
      other is CellLevel &&
      other.row == row &&
      other.column == column &&
      other.rowLevels == rowLevels &&
      other.columnLevels == columnLevels;

  @override
  int get hashCode => Object.hash(row, column, rowLevels, columnLevels);
}

/// Which level a header cell belongs to, for [HeaderColor]: a dimension's
/// title, a group's label or leg, or (on the column axis) the aggregate
/// name under an entry.
final class HeaderLevel {
  const HeaderLevel({
    required this.isRow,
    required this.level,
    required this.rowLevels,
    required this.columnLevels,
  });

  /// Row header (`true`) or column header band.
  final bool isRow;

  /// Depth on its own axis, from `0`.
  final int level;
  final int rowLevels;
  final int columnLevels;

  /// The dimension count of the header's own axis.
  int get levels => isRow ? rowLevels : columnLevels;

  /// One index over both axes, row levels first: `level` for a row header,
  /// `rowLevels + level` for a column header — what [HueLevels] uses.
  int get index => isRow ? level : rowLevels + level;

  @override
  bool operator ==(Object other) =>
      other is HeaderLevel &&
      other.isRow == isRow &&
      other.level == level &&
      other.rowLevels == rowLevels &&
      other.columnLevels == columnLevels;

  @override
  int get hashCode => Object.hash(isRow, level, rowLevels, columnLevels);
}

/// Background colour of a data cell by its [CellLevel]. Summary cells use
/// `summaryColor` instead.
typedef LevelColor = Color Function(CellLevel level);

/// Background colour of a header cell by its [HeaderLevel]. Summary
/// headers use `summaryColor` instead.
typedef HeaderColor = Color Function(HeaderLevel level);

/// Colours, text styles and dimensions of a [CubeView].
///
/// Every colour/style is optional; unset values are derived from the
/// ambient [ThemeData] when the view is built, so the default view follows
/// the app's light/dark theme.
final class CubeTheme {
  const CubeTheme({
    this.levelColor,
    this.headerColor,
    this.headerLevelColor,
    this.hueLevels,
    this.summaryColor,
    this.sortKeyColor,
    this.selectionColor,
    this.borderColor,
    this.cellTextStyle,
    this.headerTextStyle,
    this.headerIconColor,
    this.rowHeight = 28,
    this.headerRowHeight = 28,
    this.minColumnWidth = 72,
    this.maxColumnWidth = 320,
    this.minRowHeaderWidth = 100,
    this.maxRowHeaderWidth = 400,
    this.cellPadding = const EdgeInsets.symmetric(horizontal: 6),
  });

  /// Background of data cells by nesting level. Defaults to [hueLevels]
  /// when set, else a blend from the surface colour towards the primary
  /// container by [CellLevel.depth].
  final LevelColor? levelColor;

  /// Background of header cells where [headerLevelColor] does not apply
  /// (it is the default of that, and the blank corner).
  final Color? headerColor;

  /// Background of header cells by level; defaults to [hueLevels] when
  /// set, else [headerColor] everywhere.
  final HeaderColor? headerLevelColor;

  /// Colour nesting levels by hue alone (see [HueLevels]): data cells take
  /// their row level's hue, headers the same hue with more chroma, column
  /// headers continue the sequence after the row levels, summaries stay
  /// neutral. Values it leaves unset come from the app theme: the hue
  /// from the primary colour, lightness and chroma from the brightness.
  /// Explicit [levelColor] / [headerLevelColor] win over it.
  final HueLevels? hueLevels;

  /// Background of summary rows/columns (their headers and cells).
  final Color? summaryColor;

  /// Tint laid over the column (or row) whose aggregate currently drives an
  /// aggregate sort.
  final Color? sortKeyColor;

  /// Outline of the current cell; its row and column headers get a light
  /// tint of it. Defaults to the primary colour.
  final Color? selectionColor;

  final Color? borderColor;

  final TextStyle? cellTextStyle;
  final TextStyle? headerTextStyle;

  /// Colour of the icons in the headers (expand/collapse, sort arrows, the
  /// title menu button). Defaults to [headerTextStyle]'s colour, so icons
  /// stay legible on a header whose colours are pinned regardless of the
  /// app's brightness.
  final Color? headerIconColor;

  final double rowHeight;
  final double headerRowHeight;

  /// Bounds for the width of data columns. Columns are sized to their
  /// content (see [CubeView.measuredRows]) and clamped to this range; set
  /// both to the same value for fixed-width columns.
  final double minColumnWidth;
  final double maxColumnWidth;

  /// Bounds for the width of row-header columns, as above.
  final double minRowHeaderWidth;
  final double maxRowHeaderWidth;

  final EdgeInsets cellPadding;

  /// A [LevelColor] interpolating through [colors] from the top level to
  /// the deepest one ([CellLevel.depth] over [CellLevel.maxDepth]).
  static LevelColor gradient(List<Color> colors) {
    assert(colors.isNotEmpty);
    return (level) {
      final depth = level.depth, maxDepth = level.maxDepth;
      if (colors.length == 1 || maxDepth <= 0) return colors.first;
      final t = (depth / maxDepth).clamp(0.0, 1.0) * (colors.length - 1);
      final i = math.min(t.floor(), colors.length - 2);
      return Color.lerp(colors[i], colors[i + 1], t - i)!;
    };
  }

  CubeTheme copyWith({
    LevelColor? levelColor,
    Color? headerColor,
    HeaderColor? headerLevelColor,
    HueLevels? hueLevels,
    Color? summaryColor,
    Color? sortKeyColor,
    Color? selectionColor,
    Color? borderColor,
    TextStyle? cellTextStyle,
    TextStyle? headerTextStyle,
    Color? headerIconColor,
    double? rowHeight,
    double? headerRowHeight,
    double? minColumnWidth,
    double? maxColumnWidth,
    double? minRowHeaderWidth,
    double? maxRowHeaderWidth,
    EdgeInsets? cellPadding,
  }) => CubeTheme(
    levelColor: levelColor ?? this.levelColor,
    headerColor: headerColor ?? this.headerColor,
    headerLevelColor: headerLevelColor ?? this.headerLevelColor,
    hueLevels: hueLevels ?? this.hueLevels,
    summaryColor: summaryColor ?? this.summaryColor,
    sortKeyColor: sortKeyColor ?? this.sortKeyColor,
    selectionColor: selectionColor ?? this.selectionColor,
    borderColor: borderColor ?? this.borderColor,
    cellTextStyle: cellTextStyle ?? this.cellTextStyle,
    headerTextStyle: headerTextStyle ?? this.headerTextStyle,
    headerIconColor: headerIconColor ?? this.headerIconColor,
    rowHeight: rowHeight ?? this.rowHeight,
    headerRowHeight: headerRowHeight ?? this.headerRowHeight,
    minColumnWidth: minColumnWidth ?? this.minColumnWidth,
    maxColumnWidth: maxColumnWidth ?? this.maxColumnWidth,
    minRowHeaderWidth: minRowHeaderWidth ?? this.minRowHeaderWidth,
    maxRowHeaderWidth: maxRowHeaderWidth ?? this.maxRowHeaderWidth,
    cellPadding: cellPadding ?? this.cellPadding,
  );

  /// Fills in every unset value from [context]'s theme.
  ResolvedCubeTheme resolve(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final base = theme.textTheme.bodySmall ?? const TextStyle(fontSize: 12);
    final headerStyle =
        headerTextStyle ?? base.copyWith(fontWeight: FontWeight.w500);
    final hues = hueLevels?.copyWith(
      hue: hueLevels!.hue ?? Oklch.fromArgb(scheme.primary.toARGB32()).hue,
      dark: scheme.brightness == Brightness.dark,
    );
    final header = headerColor ?? scheme.surfaceContainer;
    return ResolvedCubeTheme(
      levelColor:
          levelColor ??
          (hues != null
              ? (level) => Color(hues.fill(level.row))
              : (level) => Color.lerp(
                  scheme.surface,
                  scheme.primaryContainer,
                  level.maxDepth == 0 ? 0 : 0.35 * level.depth / level.maxDepth,
                )!),
      headerColor: header,
      headerLevelColor:
          headerLevelColor ??
          (hues != null
              ? (level) => Color(hues.headerFill(level.index))
              : (_) => header),
      summaryColor: summaryColor ?? scheme.surfaceContainerHighest,
      sortKeyColor:
          sortKeyColor ?? scheme.secondaryContainer.withValues(alpha: 0.45),
      selectionColor: selectionColor ?? scheme.primary,
      borderColor: borderColor ?? scheme.outlineVariant,
      cellTextStyle: cellTextStyle ?? base,
      headerTextStyle: headerStyle,
      headerIconColor:
          headerIconColor ?? headerStyle.color ?? scheme.onSurfaceVariant,
      rowHeight: rowHeight,
      headerRowHeight: headerRowHeight,
      minColumnWidth: minColumnWidth,
      maxColumnWidth: maxColumnWidth,
      minRowHeaderWidth: minRowHeaderWidth,
      maxRowHeaderWidth: maxRowHeaderWidth,
      cellPadding: cellPadding,
    );
  }
}

/// A [CubeTheme] with every value set.
final class ResolvedCubeTheme {
  const ResolvedCubeTheme({
    required this.levelColor,
    required this.headerColor,
    required this.headerLevelColor,
    required this.summaryColor,
    required this.sortKeyColor,
    required this.selectionColor,
    required this.borderColor,
    required this.cellTextStyle,
    required this.headerTextStyle,
    required this.headerIconColor,
    required this.rowHeight,
    required this.headerRowHeight,
    required this.minColumnWidth,
    required this.maxColumnWidth,
    required this.minRowHeaderWidth,
    required this.maxRowHeaderWidth,
    required this.cellPadding,
  });

  final LevelColor levelColor;
  final Color headerColor;
  final HeaderColor headerLevelColor;
  final Color summaryColor;
  final Color sortKeyColor;
  final Color selectionColor;
  final Color borderColor;
  final TextStyle cellTextStyle;
  final TextStyle headerTextStyle;
  final Color headerIconColor;
  final double rowHeight;
  final double headerRowHeight;
  final double minColumnWidth;
  final double maxColumnWidth;
  final double minRowHeaderWidth;
  final double maxRowHeaderWidth;
  final EdgeInsets cellPadding;
}
