import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:tessera/tessera.dart';

/// Measures the texts a [CubeView] will show and derives one width per grid
/// column, so that the widest value of a column fits.
///
/// `TableView` needs every column's extent before any cell exists, so the
/// widths are computed up front from the layout. To keep that cheap for
/// large cubes only the longest few strings of a column are laid out with a
/// [TextPainter]; the rest are compared by length, which is what varies in
/// formatted numbers.
final class ColumnWidthMeasurer {
  ColumnWidthMeasurer({
    required this.cellStyle,
    required this.headerStyle,
    required this.horizontalPadding,
    required this.textDirection,
    required this.textScaler,
  });

  final TextStyle cellStyle;
  final TextStyle headerStyle;

  /// Padding plus border plus slack added to every measured text.
  final double horizontalPadding;
  final TextDirection textDirection;
  final TextScaler textScaler;

  /// Strings per column that are laid out for real; the others only
  /// contribute their length.
  static const _measured = 4;

  /// Widths of the `headerColumns` row-header columns followed by one per
  /// column entry, each clamped to the theme's bounds.
  ///
  /// [formatCell] formats a cell's value for [aggregate], whose header text
  /// is [aggregateLabel]; [rowLabel] / [columnLabel] render a header
  /// entry's text and [titleLabel] a dimension's title.
  /// [iconWidth] is the room for the expand/sort icons next to a text.
  /// Only the first [measuredRows] rows plus summary rows are visited.
  List<double> measure({
    required CubeLayout layout,
    required int headerColumns,
    required Aggregate? aggregate,
    required String aggregateLabel,
    required String Function(CubeCell cell, Object? value, bool summary)
    formatCell,
    required String Function(HeaderEntry entry) rowLabel,
    required String Function(HeaderEntry entry) columnLabel,
    required String Function(Dimension dimension) titleLabel,
    required double iconWidth,
    required int measuredRows,
    required double minColumnWidth,
    required double maxColumnWidth,
    required double minRowHeaderWidth,
    required double maxRowHeaderWidth,
  }) {
    final rows = layout.rows.entries;
    final columns = layout.columns.entries;
    final spec = layout.spec;

    // -------------------------------------------------- row-header columns
    final headers = List.generate(headerColumns, (_) => _Candidates());
    for (var c = 0; c < spec.rows.depth; c++) {
      headers[c].add(
        titleLabel(spec.rows.dimensions[c].dimension),
        header: true,
        bold: false,
        extra: iconWidth,
      );
    }
    if (headerColumns == 1) {
      // Column-dimension titles sit in the single corner column; with more
      // header columns they are merged across all of them.
      for (final d in spec.columns.dimensions) {
        headers[0].add(
          titleLabel(d.dimension),
          header: true,
          bold: false,
          extra: iconWidth,
        );
      }
    }
    for (var i = 0; i < rows.length; i++) {
      final e = rows[i];
      // A label sits in the column of its level (the summary in the first)
      // and, when collapsed, spans to the right — attributing it to its own
      // column is the conservative choice.
      headers[math.max(e.depth - 1, 0)].add(
        rowLabel(e),
        header: true,
        bold: e.isSummary,
        extra: e.isExpandable ? iconWidth : 0,
      );
    }

    // -------------------------------------------------------- data columns
    final data = List.generate(columns.length, (_) => _Candidates());
    for (var j = 0; j < columns.length; j++) {
      final e = columns[j];
      // Expanded parents span their children, so only labels that stay in
      // one column count.
      if (layout.columns.descendantCount(j) == 0) {
        data[j].add(
          columnLabel(e),
          header: true,
          bold: e.isSummary,
          extra: e.isExpandable ? iconWidth : 0,
        );
      }
    }
    if (aggregate != null) {
      for (final c in data) {
        c.add(aggregateLabel, header: true, bold: false, extra: iconWidth);
      }
      var visited = 0;
      for (var i = 0; i < rows.length; i++) {
        final rowEntry = rows[i];
        if (!rowEntry.isSummary && visited++ >= measuredRows) continue;
        for (var j = 0; j < columns.length; j++) {
          final cell = layout.cellAt(i, j);
          if (cell.isEmpty) continue;
          final summary = rowEntry.isSummary || columns[j].isSummary;
          data[j].add(
            formatCell(cell, cell.aggregate<Object?>(aggregate), summary),
            header: false,
            bold: summary,
            extra: 0,
          );
        }
      }
    }

    return [
      for (final c in headers)
        (_widest(c) + horizontalPadding).clamp(
          minRowHeaderWidth,
          maxRowHeaderWidth,
        ),
      for (final c in data)
        (_widest(c) + horizontalPadding).clamp(minColumnWidth, maxColumnWidth),
    ];
  }

  double _widest(_Candidates c) {
    var width = 0.0;
    for (final t in c.longest(_measured)) {
      final style = t.header ? headerStyle : cellStyle;
      final painter = TextPainter(
        text: TextSpan(
          text: t.text,
          style: t.bold ? style.copyWith(fontWeight: FontWeight.bold) : style,
        ),
        textDirection: textDirection,
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      width = math.max(width, painter.width + t.extra);
      painter.dispose();
    }
    return width;
  }
}

final class _Text {
  const _Text(
    this.text, {
    required this.header,
    required this.bold,
    required this.extra,
  });
  final String text;

  /// Header text style rather than cell text style.
  final bool header;
  final bool bold;
  final double extra;

  /// Length proxy used to rank candidates before measuring.
  double get score => text.length + extra / 8 + (bold ? 0.5 : 0);
}

/// Keeps the few longest strings offered to it.
final class _Candidates {
  final _texts = <_Text>[];

  void add(
    String text, {
    required bool header,
    required bool bold,
    required double extra,
  }) {
    if (text.isEmpty) return;
    _texts.add(_Text(text, header: header, bold: bold, extra: extra));
    if (_texts.length > 8 * ColumnWidthMeasurer._measured) {
      longest(ColumnWidthMeasurer._measured);
      _texts.length = ColumnWidthMeasurer._measured;
    }
  }

  /// The [n] highest-scoring texts; sorts the list in place.
  Iterable<_Text> longest(int n) {
    _texts.sort((a, b) => b.score.compareTo(a.score));
    return _texts.take(n);
  }
}
