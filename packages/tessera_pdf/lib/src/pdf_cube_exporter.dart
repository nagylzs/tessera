import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:tessera/tessera.dart';

import 'page_setup.dart';

/// Writes a [CubeLayout] — the rows and columns exactly as expanded — as a
/// paginated PDF, rendered from [CubeGrid] like the other exporters: the
/// header band (column dimension titles, group labels merged over their
/// subtree, aggregate names), the row header with group labels merged in
/// the "rotated L" shape, subtotals on the group's own row, data cells
/// right-aligned. Fills and fonts come from [theme] ([CubeExportTheme]),
/// the geometry from [GridMetrics] with the embedded fonts' exact metrics,
/// the page cuts from [GridPagination]: the header band and the row
/// header repeat on every page, a merged label that crosses a page break
/// is repeated on the continuation, text that does not fit its cell is
/// ellipsized.
///
/// Scaling: with [fitToWidth] the grid is shrunk so every column fits one
/// page width, but never below [minScale] — beyond that the columns are
/// tiled across pages (down first, then across, like a spreadsheet).
/// [header] and [footer] draw up to three texts each at the top and
/// bottom of every page.
final class PdfCubeExporter {
  const PdfCubeExporter({
    this.strings = const TesseraStringsEn(),
    this.theme = const CubeExportTheme(),
    this.pageSetup = const PageSetup(),
    this.fonts = const PdfFonts.builtIn(),
    this.header = const PdfPageText(left: '{title}'),
    this.footer = const PdfPageText(right: '{page} / {pages}'),
    this.pageTextSize = 9,
    this.fitToWidth = true,
    this.minScale = 0.6,
    this.minColumnWidth = 60,
    this.maxColumnWidth = 320,
    this.minHeaderColumnWidth = 90,
    this.maxHeaderColumnWidth = 400,
    this.cellPadding = 6,
    this.lineHeight = 1.9,
    this.emptyGroupLabel,
    this.rowSummaryLabel,
    this.columnSummaryLabel,
  }) : assert(minScale > 0 && minScale <= 1);

  final TesseraStrings strings;

  /// Colours, fonts and number format; shared with the other exporters.
  final CubeExportTheme theme;

  final PageSetup pageSetup;

  /// The fonts to embed; built-in Helvetica by default.
  final PdfFonts fonts;

  /// Texts at the top and bottom of every page (see [PdfPageText]).
  final PdfPageText header;
  final PdfPageText footer;

  /// Font size of [header] and [footer], in points.
  final double pageTextSize;

  /// Shrink the grid so every column fits the page width (down to
  /// [minScale]).
  final bool fitToWidth;

  /// The smallest scale [fitToWidth] may use; a wider grid is tiled across
  /// pages at this scale instead.
  final double minScale;

  /// Bounds of the content-sized data columns, in pixels at scale 1
  /// (96 per inch, as [GridMetrics]).
  final double minColumnWidth;
  final double maxColumnWidth;

  /// Bounds of the row header columns, in pixels.
  final double minHeaderColumnWidth;
  final double maxHeaderColumnWidth;

  /// Space between a cell's edge and its text, in pixels.
  final double cellPadding;

  /// Row height as a multiple of the font size.
  final double lineHeight;

  /// Overrides of the localized header texts, as on `CubeView`.
  final String? emptyGroupLabel;
  final String? rowSummaryLabel;
  final String? columnSummaryLabel;

  /// The document's bytes. [title] fills `{title}` in the page texts and
  /// the document's metadata; [date] fills `{date}` (default: now).
  /// [aggregates] selects and orders the value columns under each column
  /// entry; default: every aggregate of the spec.
  Future<Uint8List> export(
    CubeLayout layout, {
    List<Aggregate>? aggregates,
    String title = 'Pivot',
    DateTime? date,
  }) {
    final grid = CubeGrid.of(
      layout,
      strings: strings,
      aggregates: aggregates,
      emptyGroupLabel: emptyGroupLabel,
      rowSummaryLabel: rowSummaryLabel,
      columnSummaryLabel: columnSummaryLabel,
    );
    return _Export(this, grid, title, date ?? DateTime.now()).run();
  }

  /// The pages [export] would produce for [layout], for callers that want
  /// to know the count or the scale beforehand.
  PdfPlan plan(CubeLayout layout, {List<Aggregate>? aggregates}) {
    final grid = CubeGrid.of(
      layout,
      strings: strings,
      aggregates: aggregates,
      emptyGroupLabel: emptyGroupLabel,
      rowSummaryLabel: rowSummaryLabel,
      columnSummaryLabel: columnSummaryLabel,
    );
    return _Export(this, grid, '', DateTime.now()).plan;
  }
}

/// What [PdfCubeExporter.plan] reports: the scale applied to the grid and
/// the page cuts.
final class PdfPlan {
  const PdfPlan({required this.scale, required this.pagination});

  /// `1` = natural size (96 px per inch on screen = 72 pt on paper).
  final double scale;
  final GridPagination pagination;

  int get pageCount => pagination.pageCount;
}

const double _mm = 72 / 25.4;

/// Pixels (96 per inch) → points (72 per inch).
const double _pxToPt = 0.75;

final class _Export {
  _Export(this.exporter, this.grid, this.title, this.date)
    : theme = exporter.theme,
      doc = PdfDocument();

  final PdfCubeExporter exporter;
  final CubeGrid grid;
  final String title;
  final DateTime date;
  final CubeExportTheme theme;
  final PdfDocument doc;

  late final PdfFont _regular = _load(
    exporter.fonts.regular,
    PdfFont.helvetica,
  );
  late final PdfFont _bold = _load(
    exporter.fonts.bold,
    PdfFont.helveticaBold,
    _regular,
  );
  late final PdfFont _italic = _load(
    exporter.fonts.italic,
    PdfFont.helveticaOblique,
    _regular,
  );
  late final PdfFont _boldItalic = _load(
    exporter.fonts.boldItalic,
    PdfFont.helveticaBoldOblique,
    _bold,
  );

  PdfFont _load(
    Uint8List? bytes,
    PdfFont Function(PdfDocument) builtIn, [
    PdfFont? fallback,
  ]) {
    if (bytes != null) return PdfTtfFont(doc, ByteData.sublistView(bytes));
    if (exporter.fonts.isBuiltIn) return builtIn(doc);
    return fallback ?? builtIn(doc);
  }

  PdfFont _fontFor(ExportFont f) => f.bold
      ? (f.italic ? _boldItalic : _bold)
      : (f.italic ? _italic : _regular);

  /// Width of [text] in [font] at [size] points.
  double _width(PdfFont font, double size, String text) =>
      font.stringMetrics(text).advanceWidth * size;

  String _text(GridCell cell) => switch (cell.value) {
    null => '',
    final num v => theme.numberFormat.format(v, exporter.strings),
    final bool v => v.toString(),
    final DateTime v => v.toIso8601String(),
    final v => v.toString(),
  };

  late final GridMetrics metrics = GridMetrics.of(
    grid,
    theme: theme,
    text: _text,
    minColumnWidth: exporter.minColumnWidth,
    maxColumnWidth: exporter.maxColumnWidth,
    minHeaderColumnWidth: exporter.minHeaderColumnWidth,
    maxHeaderColumnWidth: exporter.maxHeaderColumnWidth,
    padding: exporter.cellPadding,
    lineHeight: exporter.lineHeight,
    // font metrics are per em; the estimate's unit is pixels at 96 dpi
    measure: (text, font) =>
        _width(_fontFor(font), GridMetrics.fontPixels(font.size), text),
  );

  // ------------------------------------------------------------ page geometry

  PageSetup get setup => exporter.pageSetup;
  double get pageWidth => setup.pageWidth * _mm;
  double get pageHeight => setup.pageHeight * _mm;
  double get marginLeft => setup.marginLeft * _mm;
  double get marginTop => setup.marginTop * _mm;
  double get marginBottom => setup.marginBottom * _mm;
  double get bodyWidth => setup.bodyWidth * _mm;
  double get bandHeight => exporter.pageTextSize * 1.8;
  double get headerBand => exporter.header.isEmpty ? 0 : bandHeight;
  double get footerBand => exporter.footer.isEmpty ? 0 : bandHeight;
  double get bodyHeight => setup.bodyHeight * _mm - headerBand - footerBand;

  /// Top of the grid area on a page, in PDF coordinates (y up).
  double get gridTop => pageHeight - marginTop - headerBand;

  late final PdfPlan plan = () {
    var scale = 1.0;
    if (exporter.fitToWidth) {
      final natural = metrics.width * _pxToPt;
      if (natural > bodyWidth) {
        scale = math.max(bodyWidth / natural, exporter.minScale);
      }
    }
    final k = _pxToPt * scale;
    return PdfPlan(
      scale: scale,
      pagination: GridPagination.of(
        metrics,
        frozenRows: grid.headerRows,
        frozenColumns: grid.headerColumns,
        width: bodyWidth / k,
        height: bodyHeight / k,
      ),
    );
  }();

  Future<Uint8List> run() async {
    PdfInfo(doc, title: title, creator: 'tessera_pdf');
    final pages = plan.pagination.pages;
    for (var i = 0; i < pages.length; i++) {
      final page = PdfPage(
        doc,
        pageFormat: PdfPageFormat(pageWidth, pageHeight),
      );
      final g = page.getGraphics();
      _pageTexts(g, i + 1, pages.length);
      _grid(g, pages[i]);
    }
    return doc.save();
  }

  // ------------------------------------------------------------- page texts

  void _pageTexts(PdfGraphics g, int page, int pages) {
    final size = exporter.pageTextSize;
    final font = _regular;
    g.setFillColor(PdfColor.fromInt(theme.headerFont.color));
    void band(PdfPageText text, double baseline) {
      if (text.isEmpty) return;
      String fill(String t) => PdfPageText.resolve(
        t,
        title: title,
        page: page,
        pages: pages,
        date: date,
      );
      if (text.left.isNotEmpty) {
        g.drawString(font, size, fill(text.left), marginLeft, baseline);
      }
      if (text.center.isNotEmpty) {
        final t = fill(text.center);
        g.drawString(
          font,
          size,
          t,
          marginLeft + (bodyWidth - _width(font, size, t)) / 2,
          baseline,
        );
      }
      if (text.right.isNotEmpty) {
        final t = fill(text.right);
        g.drawString(
          font,
          size,
          t,
          marginLeft + bodyWidth - _width(font, size, t),
          baseline,
        );
      }
    }

    // the header sits in its band under the top margin, the footer in
    // its band above the bottom margin; ~0.75 em ascent, 0.2 em descent
    band(exporter.header, pageHeight - marginTop - size * 0.8);
    band(exporter.footer, marginBottom + (bandHeight - size) / 2 + size * 0.2);
  }

  // ------------------------------------------------------------------- grid

  void _grid(PdfGraphics g, GridPage page) {
    final k = _pxToPt * plan.scale;
    final headerRows = grid.headerRows, headerColumns = grid.headerColumns;
    // px → page-local px: frozen rows/columns first, then the page's
    // band. Grid line `headerColumns` is both the frozen area's right edge
    // and the band's left edge, so it maps as frozen (`<=`).
    double px(int c) => c <= headerColumns
        ? metrics.x(c)
        : metrics.x(headerColumns) + metrics.x(c) - metrics.x(page.columnStart);
    double py(int r) => r <= headerRows
        ? metrics.y(r)
        : metrics.y(headerRows) + metrics.y(r) - metrics.y(page.rowStart);
    (int, int)? visible(int start, int span, int frozen, int from, int to) {
      final end = start + span;
      if (start < frozen) return (start, math.min(end, frozen));
      final s = math.max(start, from), e = math.min(end, to);
      return s < e ? (s, e) : null;
    }

    final rows = [
      for (var r = 0; r < headerRows; r++) r,
      for (var r = page.rowStart; r < page.rowEnd; r++) r,
    ];
    final columns = [
      for (var c = 0; c < headerColumns; c++) c,
      for (var c = page.columnStart; c < page.columnEnd; c++) c,
    ];
    final drawn = <int>{};
    final texts = <void Function()>[];
    g.setLineWidth(0.5);
    g.setStrokeColor(PdfColor.fromInt(theme.borderColor));
    for (final r in rows) {
      for (final c in columns) {
        final cell = grid.cellAt(r, c);
        final or = cell.originRow ?? r, oc = cell.originColumn ?? c;
        if (!drawn.add(or * grid.columnCount + oc)) continue;
        final origin = grid.cellAt(or, oc);
        final rv = visible(
          or,
          origin.rowSpan,
          headerRows,
          page.rowStart,
          page.rowEnd,
        );
        final cv = visible(
          oc,
          origin.columnSpan,
          headerColumns,
          page.columnStart,
          page.columnEnd,
        );
        if (rv == null || cv == null) continue;
        final (r0, r1) = rv;
        final (c0, c1) = cv;
        final x = marginLeft + px(c0) * k;
        final w = (px(c1) - px(c0)) * k;
        final top = gridTop - py(r0) * k;
        final h = (py(r1) - py(r0)) * k;
        g.setFillColor(PdfColor.fromInt(theme.fillOf(origin)));
        g.drawRect(x, top - h, w, h);
        g.fillAndStrokePath();
        final text = _text(origin);
        if (text.isEmpty) continue;
        texts.add(() {
          final font = _fontFor(theme.fontOf(origin));
          final size = theme.fontOf(origin).size * plan.scale;
          final pad = exporter.cellPadding * k;
          final t = _fit(font, size, text, w - 2 * pad);
          final width = _width(font, size, t);
          final tx = origin.alignRight ? x + w - pad - width : x + pad;
          // centred in the first visible row (a merged label sits on the
          // group's own row, and on the continuation's first row)
          final rowHeight = metrics.rowHeights[r0] * k;
          final baseline =
              top - rowHeight / 2 - (font.ascent + font.descent) / 2 * size;
          g.setFillColor(PdfColor.fromInt(theme.fontOf(origin).color));
          g.drawString(font, size, t, tx, baseline);
        });
      }
    }
    // texts after every fill, so a neighbour's rect never covers them
    for (final draw in texts) {
      draw();
    }
  }

  /// [text] shortened with an ellipsis to fit [available] points.
  String _fit(PdfFont font, double size, String text, double available) {
    if (_width(font, size, text) <= available) return text;
    final runes = text.runes.toList();
    var n = runes.length - 1;
    while (n > 0) {
      final t = '${String.fromCharCodes(runes.take(n))}…';
      if (_width(font, size, t) <= available) return t;
      n--;
    }
    return '';
  }
}
