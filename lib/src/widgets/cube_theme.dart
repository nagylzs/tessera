import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Background colour for cells at [depth] of [maxDepth] nesting levels
/// (`0` = top level).
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
    this.borderColor,
    this.cellTextStyle,
    this.headerTextStyle,
    this.rowHeight = 28,
    this.headerRowHeight = 28,
    this.columnWidth = 120,
    this.rowHeaderWidth = 160,
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

  final Color? borderColor;

  final TextStyle? cellTextStyle;
  final TextStyle? headerTextStyle;

  final double rowHeight;
  final double headerRowHeight;
  final double columnWidth;

  /// Width of each row-header column.
  final double rowHeaderWidth;

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
    Color? borderColor,
    TextStyle? cellTextStyle,
    TextStyle? headerTextStyle,
    double? rowHeight,
    double? headerRowHeight,
    double? columnWidth,
    double? rowHeaderWidth,
    EdgeInsets? cellPadding,
  }) => CubeTheme(
    levelColor: levelColor ?? this.levelColor,
    headerColor: headerColor ?? this.headerColor,
    summaryColor: summaryColor ?? this.summaryColor,
    sortKeyColor: sortKeyColor ?? this.sortKeyColor,
    borderColor: borderColor ?? this.borderColor,
    cellTextStyle: cellTextStyle ?? this.cellTextStyle,
    headerTextStyle: headerTextStyle ?? this.headerTextStyle,
    rowHeight: rowHeight ?? this.rowHeight,
    headerRowHeight: headerRowHeight ?? this.headerRowHeight,
    columnWidth: columnWidth ?? this.columnWidth,
    rowHeaderWidth: rowHeaderWidth ?? this.rowHeaderWidth,
    cellPadding: cellPadding ?? this.cellPadding,
  );

  /// Fills in every unset value from [context]'s theme.
  ResolvedCubeTheme resolve(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final base = theme.textTheme.bodySmall ?? const TextStyle(fontSize: 12);
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
      borderColor: borderColor ?? scheme.outlineVariant,
      cellTextStyle: cellTextStyle ?? base,
      headerTextStyle:
          headerTextStyle ?? base.copyWith(fontWeight: FontWeight.w500),
      rowHeight: rowHeight,
      headerRowHeight: headerRowHeight,
      columnWidth: columnWidth,
      rowHeaderWidth: rowHeaderWidth,
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
    required this.borderColor,
    required this.cellTextStyle,
    required this.headerTextStyle,
    required this.rowHeight,
    required this.headerRowHeight,
    required this.columnWidth,
    required this.rowHeaderWidth,
    required this.cellPadding,
  });

  final LevelColor levelColor;
  final Color headerColor;
  final Color summaryColor;
  final Color sortKeyColor;
  final Color borderColor;
  final TextStyle cellTextStyle;
  final TextStyle headerTextStyle;
  final double rowHeight;
  final double headerRowHeight;
  final double columnWidth;
  final double rowHeaderWidth;
  final EdgeInsets cellPadding;
}
