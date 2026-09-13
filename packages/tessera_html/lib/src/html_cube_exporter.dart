import 'package:tessera/tessera.dart';

/// Where the theme's styling goes.
enum HtmlStyling {
  /// A `<style>` element with rules on the `tessera-…` classes (embedded
  /// in the document or fragment).
  stylesheet,

  /// `style` attributes on every cell — for e-mail clients and other
  /// places that strip stylesheets.
  inline,

  /// Classes only; the page supplies the CSS.
  none,
}

/// Writes a [CubeLayout] — the rows and columns exactly as expanded — as
/// an HTML table, rendered from [CubeGrid] like the other exporters: the
/// header band in `<thead>` (column dimension titles, group labels merged
/// with `colspan`/`rowspan`, aggregate names), the row header and data in
/// `<tbody>` with group labels merged over their subtree, subtotals on the
/// group's own row. Every cell carries classes for its kind and level so a
/// page can restyle it: `tessera-title`, `tessera-header`, `tessera-leg`,
/// `tessera-aggregate`, `tessera-data`, `tessera-summary`,
/// `tessera-level-N`, `tessera-row-level-N` / `tessera-col-level-N` (the
/// level a header cell belongs to), `tessera-num`.
final class HtmlCubeExporter {
  const HtmlCubeExporter({
    this.strings = const TesseraStringsEn(),
    this.theme = const CubeExportTheme(),
    this.styling = HtmlStyling.stylesheet,
    this.stickyHeaders = true,
    this.classPrefix = 'tessera',
    this.emptyGroupLabel,
    this.rowSummaryLabel,
    this.columnSummaryLabel,
  });

  final TesseraStrings strings;

  /// Colours, fonts and number format; shared with the other exporters.
  final CubeExportTheme theme;

  final HtmlStyling styling;

  /// Keep the header rows visible while the table scrolls
  /// (`position: sticky`; needs [styling] to be [HtmlStyling.stylesheet]).
  final bool stickyHeaders;

  /// Prefix of the generated class names (`tessera-data`, …).
  final String classPrefix;

  /// Overrides of the localized header texts, as on `CubeView`.
  final String? emptyGroupLabel;
  final String? rowSummaryLabel;
  final String? columnSummaryLabel;

  /// The HTML. With [standalone] a whole document (`<!DOCTYPE html>`,
  /// [title], the stylesheet in `<head>`), otherwise a fragment — the
  /// `<table>` preceded by the `<style>` element when [styling] is
  /// [HtmlStyling.stylesheet] — to drop into a page. [aggregates] selects
  /// and orders the value columns under each column entry; default: every
  /// aggregate of the spec.
  String export(
    CubeLayout layout, {
    List<Aggregate>? aggregates,
    String title = 'Pivot',
    bool standalone = true,
  }) {
    final grid = CubeGrid.of(
      layout,
      strings: strings,
      aggregates: aggregates,
      emptyGroupLabel: emptyGroupLabel,
      rowSummaryLabel: rowSummaryLabel,
      columnSummaryLabel: columnSummaryLabel,
    );
    final b = StringBuffer();
    final css = styling == HtmlStyling.stylesheet ? stylesheet() : null;
    if (standalone) {
      b.write(
        '<!DOCTYPE html>\n<html lang="${escape(strings.languageCode)}">\n<head>\n'
        '<meta charset="utf-8">\n<title>${escape(title)}</title>\n',
      );
      if (css != null) b.write('<style>\n$css</style>\n');
      b.write('</head>\n<body>\n');
    } else if (css != null) {
      b.write('<style>\n$css</style>\n');
    }
    _table(b, grid, title);
    if (standalone) b.write('</body>\n</html>\n');
    return b.toString();
  }

  /// The CSS rules for the `classPrefix-…` classes derived from [theme]
  /// (what [HtmlStyling.stylesheet] embeds), for pages that want to serve
  /// it themselves.
  String stylesheet() {
    final p = classPrefix;
    final b = StringBuffer();
    b.writeln(
      'table.$p { border-collapse: collapse; ${_font(theme.cellFont)} }',
    );
    b.writeln(
      'table.$p th, table.$p td { border: 1px solid ${_rgb(theme.borderColor)}; '
      'padding: 2px 6px; text-align: left; vertical-align: top; white-space: nowrap; }',
    );
    b.writeln(
      'table.$p th { background: ${_rgb(theme.headerFill)}; ${_font(theme.headerFont)} }',
    );
    b.writeln('table.$p .$p-num { text-align: right; }');
    for (var i = 0; i < theme.levelFills.length; i++) {
      b.writeln(
        'table.$p td.$p-level-$i { background: ${_rgb(theme.levelFills[i])}; }',
      );
    }
    for (var i = 0; i < theme.rowHeaderFills.length; i++) {
      b.writeln(
        'table.$p th.$p-row-level-$i { background: ${_rgb(theme.rowHeaderFills[i])}; }',
      );
    }
    for (var i = 0; i < theme.columnHeaderFills.length; i++) {
      b.writeln(
        'table.$p th.$p-col-level-$i { background: ${_rgb(theme.columnHeaderFills[i])}; }',
      );
    }
    b.writeln(
      'table.$p .$p-summary { background: ${_rgb(theme.summaryFill)}; ${_font(theme.summaryFont)} }',
    );
    if (stickyHeaders) {
      b.writeln('table.$p thead th { position: sticky; top: 0; z-index: 1; }');
    }
    return b.toString();
  }

  void _table(StringBuffer b, CubeGrid grid, String title) {
    final p = classPrefix;
    b.write('<table class="$p"');
    if (styling == HtmlStyling.inline) {
      b.write(' style="border-collapse: collapse; ${_font(theme.cellFont)}"');
    }
    b.write('>\n');
    b.write('<caption>${escape(title)}</caption>\n');
    b.write('<thead>\n');
    for (var r = 0; r < grid.rowCount; r++) {
      if (r == grid.headerRows) b.write('</thead>\n<tbody>\n');
      b.write('<tr>');
      for (var c = 0; c < grid.columnCount; c++) {
        final cell = grid.cellAt(r, c);
        if (!cell.isOrigin) continue; // covered by a rowspan/colspan
        final isHeader =
            cell.kind != GridCellKind.data && c < grid.headerColumns ||
            r < grid.headerRows;
        final tag = isHeader ? 'th' : 'td';
        b.write('<$tag');
        if (cell.rowSpan > 1) b.write(' rowspan="${cell.rowSpan}"');
        if (cell.columnSpan > 1) b.write(' colspan="${cell.columnSpan}"');
        if (isHeader && c < grid.headerColumns && r >= grid.headerRows) {
          b.write(' scope="row"');
        } else if (isHeader && r < grid.headerRows) {
          b.write(' scope="col"');
        }
        b.write(' class="${_classes(cell)}"');
        if (styling == HtmlStyling.inline) b.write(' style="${_inline(cell)}"');
        b.write('>${escape(_text(cell))}</$tag>');
      }
      b.write('</tr>\n');
    }
    b.write('</tbody>\n</table>\n');
  }

  String _classes(GridCell cell) {
    final p = classPrefix;
    final out = <String>[
      switch (cell.kind) {
        GridCellKind.blank => '$p-blank',
        GridCellKind.columnTitle || GridCellKind.rowTitle => '$p-title',
        GridCellKind.columnLabel ||
        GridCellKind.rowLabel => cell.isLeg ? '$p-leg' : '$p-header',
        GridCellKind.aggregateLabel => '$p-aggregate',
        GridCellKind.data => '$p-data',
      },
      if (cell.isSummary) '$p-summary',
      if (cell.kind == GridCellKind.data && !cell.isSummary)
        '$p-level-${_clampTo(theme.levelOf(cell), theme.levelFills)}',
      if (!cell.isSummary &&
          cell.kind != GridCellKind.data &&
          cell.rowLevel >= 0)
        '$p-row-level-${_clampTo(cell.rowLevel, theme.rowHeaderFills)}',
      if (!cell.isSummary &&
          cell.kind != GridCellKind.data &&
          cell.columnLevel >= 0)
        '$p-col-level-${_clampTo(cell.columnLevel, theme.columnHeaderFills)}',
      if (cell.alignRight) '$p-num',
    ];
    return out.join(' ');
  }

  /// [level] limited to the indices of [fills] (as the theme repeats the
  /// last fill), or itself when there are no fills to match.
  static int _clampTo(int level, List<int> fills) =>
      fills.isEmpty ? level : level.clamp(0, fills.length - 1);

  String _inline(GridCell cell) {
    final fill = theme.fillOf(cell);
    final font = theme.fontOf(cell);
    return 'border: 1px solid ${_rgb(theme.borderColor)}; padding: 2px 6px; '
        'white-space: nowrap; background: ${_rgb(fill)}; ${_font(font)} '
        'text-align: ${cell.alignRight ? 'right' : 'left'};';
  }

  String _text(GridCell cell) => switch (cell.value) {
    null => '',
    final num v => formatNumber(v),
    final bool v => v.toString(),
    final DateTime v => v.toIso8601String(),
    final v => v.toString(),
  };

  /// [v] with the theme's decimals and grouping and the locale's
  /// separators ([NumberFormat.format]).
  String formatNumber(num v) => theme.numberFormat.format(v, strings);

  static String _font(ExportFont f) =>
      'font-family: ${_quoteFamily(f.family)}; font-size: ${_pt(f.size)}pt; '
      'color: ${_rgb(f.color)};'
      '${f.bold ? ' font-weight: bold;' : ''}'
      '${f.italic ? ' font-style: italic;' : ''}';

  static String _quoteFamily(String family) =>
      family.contains(' ') ? '"${escape(family)}"' : escape(family);

  static String _pt(double size) => size == size.truncateToDouble()
      ? size.toInt().toString()
      : size.toString();

  static String _rgb(int argb) =>
      '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  static String escape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
