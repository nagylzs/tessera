import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Background colour for data cells at [depth] of [maxDepth] nesting
/// levels. A cell's depth is the row group's depth plus the column group's
/// depth, counted from `0` for the cells of the first row level × the
/// first column level; [maxDepth] is the deepest possible cell (every level
/// of both axes open). Summary cells use `summaryColor` instead.
typedef LevelColor = Color Function(int depth, int maxDepth);

/// Colours, text styles and dimensions of a [CubeView].
///
/// Every colour/style is optional; unset values are derived from the
/// ambient [ThemeData] when the view is built, so the default view follows
/// the app's light/dark theme.
final class CubeTheme {
  const CubeTheme({
    this.levelColor,
    this.headerColor,
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

  /// Background of data cells by nesting level. Defaults to a blend from
  /// the surface colour towards the primary container.
  final LevelColor? levelColor;

  /// Background of header cells.
  final Color? headerColor;

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
  /// the deepest one.
  static LevelColor gradient(List<Color> colors) {
    assert(colors.isNotEmpty);
    return (depth, maxDepth) {
      if (colors.length == 1 || maxDepth <= 0) return colors.first;
      final t = (depth / maxDepth).clamp(0.0, 1.0) * (colors.length - 1);
      final i = math.min(t.floor(), colors.length - 2);
      return Color.lerp(colors[i], colors[i + 1], t - i)!;
    };
  }

  CubeTheme copyWith({
    LevelColor? levelColor,
    Color? headerColor,
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
    return ResolvedCubeTheme(
      levelColor:
          levelColor ??
          (depth, maxDepth) => Color.lerp(
            scheme.surface,
            scheme.primaryContainer,
            maxDepth == 0 ? 0 : 0.35 * depth / maxDepth,
          )!,
      headerColor: headerColor ?? scheme.surfaceContainer,
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
