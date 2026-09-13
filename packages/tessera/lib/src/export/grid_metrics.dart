import 'dart:math' as math;

import 'cube_export_theme.dart';
import 'cube_grid.dart';

/// Width of [text] set in [font], in pixels (96 per inch).
typedef TextMeasurer = double Function(String text, ExportFont font);

/// Pixel geometry of a [CubeGrid] for renderers that lay the cells out
/// themselves (SVG, PDF, canvases): content-sized column widths, row
/// heights from the fonts, and the cumulative offsets of every grid line.
///
/// Pure Dart cannot measure text, so widths are *estimated* from the
/// characters and the font size ([estimateWidth]) unless a [TextMeasurer]
/// is given (a Flutter app can pass a `TextPainter`); a renderer should
/// clip text to its cell so a font that differs from the estimate
/// overflows nothing. Merged cells widen the columns they span when their
/// text needs it. Sizes are in pixels at 96 dpi; fonts are in points.
final class GridMetrics {
  GridMetrics._(
    this.columnWidths,
    this.rowHeights,
    this.columnOffsets,
    this.rowOffsets,
  );

  /// Lays [grid] out. [text] gives each cell's text (formatted numbers
  /// included) so this class needs no locale. The width bounds are per
  /// column: [minHeaderColumnWidth] / [maxHeaderColumnWidth] for the row
  /// header columns, [minColumnWidth] / [maxColumnWidth] for the rest;
  /// [padding] is on both sides of the text; [lineHeight] is the row
  /// height as a multiple of the font size.
  factory GridMetrics.of(
    CubeGrid grid, {
    required CubeExportTheme theme,
    required String Function(GridCell cell) text,
    double minColumnWidth = 60,
    double maxColumnWidth = 320,
    double minHeaderColumnWidth = 90,
    double maxHeaderColumnWidth = 400,
    double padding = 6,
    double lineHeight = 1.9,
    TextMeasurer? measure,
  }) {
    final measurer = measure ?? estimateWidth;
    final columns = grid.columnCount, rows = grid.rowCount;
    final needed = List<double>.filled(columns, 0);
    final merged = <(int, int, int, double)>[]; // (row, column, span, need)
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < columns; c++) {
        final cell = grid.cellAt(r, c);
        if (!cell.isOrigin) continue;
        final t = text(cell);
        if (t.isEmpty) continue;
        final need = measurer(t, theme.fontOf(cell)) + 2 * padding;
        if (cell.columnSpan == 1) {
          needed[c] = math.max(needed[c], need);
        } else {
          merged.add((r, c, cell.columnSpan, need));
        }
      }
    }
    final widths = [
      for (var c = 0; c < columns; c++)
        c < grid.headerColumns
            ? needed[c].clamp(minHeaderColumnWidth, maxHeaderColumnWidth)
            : needed[c].clamp(minColumnWidth, maxColumnWidth),
    ];
    for (final (_, c, span, need) in merged) {
      var have = 0.0;
      for (var k = 0; k < span; k++) {
        have += widths[c + k];
      }
      final maxWidth = c < grid.headerColumns
          ? maxHeaderColumnWidth
          : maxColumnWidth;
      final short = math.min(need, span * maxWidth) - have;
      if (short <= 0) continue;
      for (var k = 0; k < span; k++) {
        widths[c + k] += short / span;
      }
    }
    final heights = [
      for (var r = 0; r < rows; r++)
        (_fontPx(
                  r < grid.headerRows
                      ? math.max(theme.headerFont.size, theme.summaryFont.size)
                      : math.max(theme.cellFont.size, theme.summaryFont.size),
                ) *
                lineHeight)
            .ceilToDouble(),
    ];
    return GridMetrics._(
      List.unmodifiable([for (final w in widths) w.ceilToDouble()]),
      List.unmodifiable(heights),
      List.unmodifiable(_offsets(widths.map((w) => w.ceilToDouble()))),
      List.unmodifiable(_offsets(heights)),
    );
  }

  /// Width of every grid column, in pixels.
  final List<double> columnWidths;

  /// Height of every grid row, in pixels.
  final List<double> rowHeights;

  /// `columnOffsets[c]` is the x of column `c`'s left edge; one more entry
  /// than columns, the last being the total [width].
  final List<double> columnOffsets;

  /// `rowOffsets[r]` is the y of row `r`'s top edge; the last entry is
  /// [height].
  final List<double> rowOffsets;

  double get width => columnOffsets.last;
  double get height => rowOffsets.last;

  /// Left edge of column [c].
  double x(int c) => columnOffsets[c];

  /// Top edge of row [r].
  double y(int r) => rowOffsets[r];

  /// Width of [span] columns from [c].
  double spanWidth(int c, int span) =>
      columnOffsets[c + span] - columnOffsets[c];

  /// Height of [span] rows from [r].
  double spanHeight(int r, int span) => rowOffsets[r + span] - rowOffsets[r];

  /// Width of [text] set in [font] without measuring it: an average glyph
  /// width per character class (digits and capitals wide, punctuation
  /// narrow) times the font's pixel size, a little more when bold.
  static double estimateWidth(String text, ExportFont font) {
    var em = 0.0;
    for (final unit in text.runes) {
      em += switch (unit) {
        >= 0x30 && <= 0x39 => 0.58, // digits
        >= 0x41 && <= 0x5A => 0.68, // capitals
        0x20 || 0x2E || 0x2C || 0x3A || 0x3B || 0x27 || 0x7C => 0.28,
        0x69 || 0x6A || 0x6C || 0x74 || 0x66 || 0x72 => 0.3, // i j l t f r
        0x6D || 0x77 => 0.83, // m w
        _ => 0.55,
      };
    }
    return em * _fontPx(font.size) * (font.bold ? 1.07 : 1);
  }

  /// [pt] points in pixels at 96 dpi.
  static double fontPixels(double pt) => _fontPx(pt);

  static double _fontPx(double pt) => pt * 96 / 72;

  static List<double> _offsets(Iterable<double> sizes) {
    final out = <double>[0];
    for (final s in sizes) {
      out.add(out.last + s);
    }
    return out;
  }
}
