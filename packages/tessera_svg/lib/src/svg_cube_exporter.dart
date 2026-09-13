import 'package:tessera/tessera.dart';

/// Draws a [CubeLayout] — the rows and columns exactly as expanded — as an
/// SVG image, rendered from [CubeGrid] like the other exporters: the
/// header band (column dimension titles, group labels merged over their
/// subtree, aggregate names), the row header with group labels merged in
/// the "rotated L" shape, subtotals on the group's own row, data cells
/// right-aligned. Fills and fonts come from [theme] ([CubeExportTheme]),
/// the geometry from [GridMetrics]: columns are sized to their content
/// with an estimate of the text width (or [measureText] when given) and
/// every text is clipped to its cell, so a viewer's font that differs
/// from the estimate overflows nothing.
///
/// The image has a `viewBox`, so it scales; `width`/`height` are the
/// natural pixel size at 96 dpi. Each cell is a `<rect>` (class
/// `tessera-title` / `-header` / `-leg` / `-aggregate` / `-data`, plus
/// `-summary`) followed by its `<text>`, so a page can restyle or script
/// it.
final class SvgCubeExporter {
  const SvgCubeExporter({
    this.strings = const TesseraStringsEn(),
    this.theme = const CubeExportTheme(),
    this.minColumnWidth = 60,
    this.maxColumnWidth = 320,
    this.minHeaderColumnWidth = 90,
    this.maxHeaderColumnWidth = 400,
    this.cellPadding = 6,
    this.lineHeight = 1.9,
    this.measureText,
    this.classPrefix = 'tessera',
    this.xmlDeclaration = true,
    this.emptyGroupLabel,
    this.rowSummaryLabel,
    this.columnSummaryLabel,
  });

  final TesseraStrings strings;

  /// Colours, fonts and number format; shared with the other exporters.
  final CubeExportTheme theme;

  /// Bounds of the content-sized data columns, in pixels.
  final double minColumnWidth;
  final double maxColumnWidth;

  /// Bounds of the row header columns, in pixels.
  final double minHeaderColumnWidth;
  final double maxHeaderColumnWidth;

  /// Space between a cell's edge and its text, in pixels.
  final double cellPadding;

  /// Row height as a multiple of the font size.
  final double lineHeight;

  /// Measures text for the column widths instead of the built-in estimate
  /// ([GridMetrics.estimateWidth]); width in pixels at 96 dpi.
  final TextMeasurer? measureText;

  /// Prefix of the class names on the cells (`tessera-data`, …).
  final String classPrefix;

  /// Start with `<?xml …?>`; off for inlining into HTML.
  final bool xmlDeclaration;

  /// Overrides of the localized header texts, as on `CubeView`.
  final String? emptyGroupLabel;
  final String? rowSummaryLabel;
  final String? columnSummaryLabel;

  /// The SVG document. [title] becomes the image's `<title>` (what
  /// screen readers and tooltips show). [aggregates] selects and orders
  /// the value columns under each column entry; default: every aggregate
  /// of the spec.
  String export(
    CubeLayout layout, {
    List<Aggregate>? aggregates,
    String title = 'Pivot',
  }) {
    final grid = CubeGrid.of(
      layout,
      strings: strings,
      aggregates: aggregates,
      emptyGroupLabel: emptyGroupLabel,
      rowSummaryLabel: rowSummaryLabel,
      columnSummaryLabel: columnSummaryLabel,
    );
    final metrics = metricsOf(grid);
    final b = StringBuffer();
    if (xmlDeclaration) b.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    final w = _num(metrics.width), h = _num(metrics.height);
    b.writeln(
      '<svg xmlns="http://www.w3.org/2000/svg" width="$w" height="$h" '
      'viewBox="0 0 $w $h" ${_fontAttributes(theme.cellFont)}>',
    );
    b.writeln('<title>${escape(title)}</title>');
    _clipPaths(b, grid, metrics);
    b.writeln(
      '<g stroke="${_rgb(theme.borderColor)}" stroke-width="1" '
      'shape-rendering="crispEdges">',
    );
    for (var r = 0; r < grid.rowCount; r++) {
      for (var c = 0; c < grid.columnCount; c++) {
        final cell = grid.cellAt(r, c);
        if (!cell.isOrigin) continue;
        b.writeln(
          '<rect class="${_classes(cell)}" x="${_num(metrics.x(c))}" '
          'y="${_num(metrics.y(r))}" '
          'width="${_num(metrics.spanWidth(c, cell.columnSpan))}" '
          'height="${_num(metrics.spanHeight(r, cell.rowSpan))}" '
          'fill="${_rgb(theme.fillOf(cell))}"/>',
        );
      }
    }
    b.writeln('</g>');
    b.writeln('<g>');
    for (var r = 0; r < grid.rowCount; r++) {
      for (var c = 0; c < grid.columnCount; c++) {
        final cell = grid.cellAt(r, c);
        if (!cell.isOrigin) continue;
        final text = _text(cell);
        if (text.isEmpty) continue;
        final font = theme.fontOf(cell);
        final left = metrics.x(c), top = metrics.y(r);
        final width = metrics.spanWidth(c, cell.columnSpan);
        final x = cell.alignRight
            ? left + width - cellPadding
            : left + cellPadding;
        // vertically centred in the cell's first row (a merged label sits
        // on the group's own row, as in CubeView); the baseline is about
        // 0.35 em below the centre line
        final y =
            top +
            metrics.rowHeights[r] / 2 +
            GridMetrics.fontPixels(font.size) * 0.35;
        final clip = cell.isMerged ? 'm${r}_$c' : 'c$c';
        b.writeln(
          '<text x="${_num(x)}" y="${_num(y)}" '
          '${cell.alignRight ? 'text-anchor="end" ' : ''}'
          'clip-path="url(#$clip)" ${_fontAttributes(font)}>'
          '${escape(text)}</text>',
        );
      }
    }
    b.writeln('</g>');
    b.writeln('</svg>');
    return b.toString();
  }

  /// The geometry [export] draws with, for callers that overlay or
  /// paginate the image.
  GridMetrics metricsOf(CubeGrid grid) => GridMetrics.of(
    grid,
    theme: theme,
    text: _text,
    minColumnWidth: minColumnWidth,
    maxColumnWidth: maxColumnWidth,
    minHeaderColumnWidth: minHeaderColumnWidth,
    maxHeaderColumnWidth: maxHeaderColumnWidth,
    padding: cellPadding,
    lineHeight: lineHeight,
    measure: measureText,
  );

  /// One clip rectangle per column (for its single-column texts) and one
  /// per merged cell with text.
  void _clipPaths(StringBuffer b, CubeGrid grid, GridMetrics metrics) {
    b.writeln('<defs>');
    for (var c = 0; c < grid.columnCount; c++) {
      b.writeln(
        '<clipPath id="c$c"><rect x="${_num(metrics.x(c))}" y="0" '
        'width="${_num(metrics.columnWidths[c])}" '
        'height="${_num(metrics.height)}"/></clipPath>',
      );
    }
    for (var r = 0; r < grid.rowCount; r++) {
      for (var c = 0; c < grid.columnCount; c++) {
        final cell = grid.cellAt(r, c);
        if (!cell.isOrigin || !cell.isMerged || _text(cell).isEmpty) continue;
        b.writeln(
          '<clipPath id="m${r}_$c"><rect x="${_num(metrics.x(c))}" '
          'y="${_num(metrics.y(r))}" '
          'width="${_num(metrics.spanWidth(c, cell.columnSpan))}" '
          'height="${_num(metrics.spanHeight(r, cell.rowSpan))}"/></clipPath>',
        );
      }
    }
    b.writeln('</defs>');
  }

  String _classes(GridCell cell) {
    final p = classPrefix;
    return [
      switch (cell.kind) {
        GridCellKind.blank => '$p-blank',
        GridCellKind.columnTitle || GridCellKind.rowTitle => '$p-title',
        GridCellKind.columnLabel ||
        GridCellKind.rowLabel => cell.isLeg ? '$p-leg' : '$p-header',
        GridCellKind.aggregateLabel => '$p-aggregate',
        GridCellKind.data => '$p-data',
      },
      if (cell.isSummary) '$p-summary',
    ].join(' ');
  }

  String _text(GridCell cell) => switch (cell.value) {
    null => '',
    final num v => theme.numberFormat.format(v, strings),
    final bool v => v.toString(),
    final DateTime v => v.toIso8601String(),
    final v => v.toString(),
  };

  static String _fontAttributes(ExportFont f) =>
      'font-family="${escape(f.family)}" '
      'font-size="${_num(GridMetrics.fontPixels(f.size))}" '
      'fill="${_rgb(f.color)}"'
      '${f.bold ? ' font-weight="bold"' : ''}'
      '${f.italic ? ' font-style="italic"' : ''}';

  static String _num(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  static String _rgb(int argb) =>
      '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  /// [s] with the XML special characters escaped.
  static String escape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
