import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:tessera/tessera.dart';

/// Writes a [CubeLayout] — the rows and columns exactly as expanded — as a
/// formatted OpenDocument sheet, rendered from [CubeGrid] like the other
/// exporters: merged "rotated L" group headers, one column per exported
/// aggregate, subtotals on the group's own row, fills, fonts and the
/// number format from [theme], labels from [strings].
final class OdsCubeExporter {
  const OdsCubeExporter({
    this.strings = const TesseraStringsEn(),
    this.theme = const CubeExportTheme(),
    this.freezeHeaders = true,
    this.minColumnWidth = 8,
    this.maxColumnWidth = 60,
    this.emptyGroupLabel,
    this.rowSummaryLabel,
    this.columnSummaryLabel,
  });

  final TesseraStrings strings;

  /// Colours, fonts and number format; shared with the other exporters.
  final CubeExportTheme theme;

  /// Freeze the header rows and columns (a view setting in `settings.xml`).
  final bool freezeHeaders;

  /// Bounds of the content-sized column widths, in characters.
  final double minColumnWidth;
  final double maxColumnWidth;

  /// Overrides of the localized header texts, as on `CubeView`.
  final String? emptyGroupLabel;
  final String? rowSummaryLabel;
  final String? columnSummaryLabel;

  /// The document bytes. [aggregates] selects and orders the value columns
  /// under each column entry; default: every aggregate of the spec.
  Uint8List export(
    CubeLayout layout, {
    List<Aggregate>? aggregates,
    String sheetName = 'Pivot',
  }) {
    final grid = CubeGrid.of(
      layout,
      strings: strings,
      aggregates: aggregates,
      emptyGroupLabel: emptyGroupLabel,
      rowSummaryLabel: rowSummaryLabel,
      columnSummaryLabel: columnSummaryLabel,
    );
    return _Writer(this, grid, sheetName).build();
  }
}

final class _Writer {
  _Writer(this.exporter, this.grid, this.sheetName);

  final OdsCubeExporter exporter;
  final CubeGrid grid;
  final String sheetName;

  CubeExportTheme get theme => exporter.theme;

  final _styles = <_CellStyle>[];
  final _styleIndex = <_CellStyle, int>{};
  final _fonts = <String>{};

  static const _mime = 'application/vnd.oasis.opendocument.spreadsheet';

  Uint8List build() {
    final rows = _rows(); // registers styles and fonts
    final archive = Archive();
    archive.add(
      ArchiveFile.string('mimetype', _mime)..compression = CompressionType.none,
    );
    archive.add(
      ArchiveFile.string(
        'META-INF/manifest.xml',
        _manifest(withSettings: exporter.freezeHeaders),
      ),
    );
    archive.add(ArchiveFile.string('content.xml', _content(rows)));
    archive.add(ArchiveFile.string('styles.xml', _stylesXml));
    if (exporter.freezeHeaders) {
      archive.add(ArchiveFile.string('settings.xml', _settings()));
    }
    return ZipEncoder().encodeBytes(archive);
  }

  // ------------------------------------------------------------------ cells

  int _styleOf(GridCell cell) {
    final font = theme.fontOf(cell);
    final fill = theme.fillOf(cell);
    _fonts.add(font.family);
    final style = _CellStyle(fill, font, cell.alignRight);
    return _styleIndex.putIfAbsent(style, () {
      _styles.add(style);
      return _styles.length - 1;
    });
  }

  /// The `<table:table-row>` elements, and the widest text per column.
  late final List<int> _longest = List.filled(grid.columnCount, 0);

  String _rows() {
    final b = StringBuffer();
    final decimals = theme.numberFormat.decimals;
    for (var r = 0; r < grid.rowCount; r++) {
      b.write('<table:table-row>');
      for (var c = 0; c < grid.columnCount; c++) {
        final cell = grid.cellAt(r, c);
        final s = 'ce${_styleOf(cell)}';
        if (!cell.isOrigin) {
          b.write('<table:covered-table-cell table:style-name="$s"/>');
          continue;
        }
        final span = cell.isMerged
            ? ' table:number-columns-spanned="${cell.columnSpan}"'
                  ' table:number-rows-spanned="${cell.rowSpan}"'
            : '';
        final value = cell.value;
        if (value == null) {
          b.write('<table:table-cell table:style-name="$s"$span/>');
          continue;
        }
        final String text;
        switch (value) {
          case num v when v.isFinite:
            text = v is int ? v.toString() : v.toStringAsFixed(decimals);
            b.write(
              '<table:table-cell table:style-name="$s"$span '
              'office:value-type="float" office:value="$v">',
            );
          case bool v:
            text = v ? 'TRUE' : 'FALSE';
            b.write(
              '<table:table-cell table:style-name="$s"$span '
              'office:value-type="boolean" office:boolean-value="$v">',
            );
          default:
            text = value is DateTime
                ? value.toIso8601String()
                : value.toString();
            b.write(
              '<table:table-cell table:style-name="$s"$span '
              'office:value-type="string">',
            );
        }
        b.write('<text:p>${_escape(text)}</text:p></table:table-cell>');
        if (cell.columnSpan == 1 && text.length > _longest[c]) {
          _longest[c] = text.length;
        }
      }
      b.write('</table:table-row>');
    }
    return b.toString();
  }

  // ---------------------------------------------------------------- parts

  String _content(String rows) {
    final b = StringBuffer(
      '<?xml version="1.0" encoding="UTF-8"?>\n'
      '<office:document-content '
      'xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" '
      'xmlns:style="urn:oasis:names:tc:opendocument:xmlns:style:1.0" '
      'xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" '
      'xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0" '
      'xmlns:fo="urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0" '
      'xmlns:number="urn:oasis:names:tc:opendocument:xmlns:datastyle:1.0" '
      'xmlns:svg="urn:oasis:names:tc:opendocument:xmlns:svg-compatible:1.0" '
      'office:version="1.3">',
    );
    b.write('<office:font-face-decls>');
    for (final f in _fonts) {
      b.write(
        '<style:font-face style:name="${_escape(f)}" svg:font-family="${_escape(f)}"/>',
      );
    }
    b.write('</office:font-face-decls>');
    b.write('<office:automatic-styles>');
    final nf = theme.numberFormat;
    b.write(
      '<number:number-style style:name="N1"><number:number '
      'number:decimal-places="${nf.decimals}" number:min-decimal-places="${nf.decimals}" '
      'number:min-integer-digits="1"${nf.grouping ? ' number:grouping="true"' : ''}/>'
      '</number:number-style>',
    );
    for (var c = 0; c < grid.columnCount; c++) {
      final chars = (_longest[c] * 1.1 + 2).clamp(
        exporter.minColumnWidth,
        exporter.maxColumnWidth,
      );
      b.write(
        '<style:style style:name="co$c" style:family="table-column">'
        '<style:table-column-properties style:column-width="${(chars * 0.2).toStringAsFixed(2)}cm"/>'
        '</style:style>',
      );
    }
    final border = '0.5pt solid ${_rgb(theme.borderColor)}';
    for (var i = 0; i < _styles.length; i++) {
      final s = _styles[i];
      b.write(
        '<style:style style:name="ce$i" style:family="table-cell" '
        'style:data-style-name="N1">'
        '<style:table-cell-properties fo:background-color="${_rgb(s.fill)}" '
        'fo:border="$border" style:vertical-align="middle"/>'
        '<style:paragraph-properties fo:text-align="${s.right ? 'end' : 'start'}"/>'
        '<style:text-properties style:font-name="${_escape(s.font.family)}" '
        'fo:font-size="${_pt(s.font.size)}pt" fo:color="${_rgb(s.font.color)}"'
        '${s.font.bold ? ' fo:font-weight="bold"' : ''}'
        '${s.font.italic ? ' fo:font-style="italic"' : ''}/>'
        '</style:style>',
      );
    }
    b.write('</office:automatic-styles>');
    b.write('<office:body><office:spreadsheet>');
    b.write('<table:table table:name="${_escape(sheetName)}">');
    for (var c = 0; c < grid.columnCount; c++) {
      b.write('<table:table-column table:style-name="co$c"/>');
    }
    b.write(rows);
    b.write('</table:table></office:spreadsheet></office:body>');
    b.write('</office:document-content>');
    return b.toString();
  }

  static String _manifest({required bool withSettings}) =>
      '<?xml version="1.0" encoding="UTF-8"?>\n'
      '<manifest:manifest xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0" manifest:version="1.3">'
      '<manifest:file-entry manifest:full-path="/" manifest:version="1.3" manifest:media-type="$_mime"/>'
      '<manifest:file-entry manifest:full-path="content.xml" manifest:media-type="text/xml"/>'
      '<manifest:file-entry manifest:full-path="styles.xml" manifest:media-type="text/xml"/>'
      '${withSettings ? '<manifest:file-entry manifest:full-path="settings.xml" manifest:media-type="text/xml"/>' : ''}'
      '</manifest:manifest>';

  static const _stylesXml =
      '<?xml version="1.0" encoding="UTF-8"?>\n'
      '<office:document-styles xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" '
      'office:version="1.3"><office:styles/></office:document-styles>';

  /// Freezes [CubeGrid.headerRows] rows and [CubeGrid.headerColumns]
  /// columns of the sheet.
  String _settings() {
    final cols = grid.headerColumns, rows = grid.headerRows;
    String item(String name, String type, Object value) =>
        '<config:config-item config:name="$name" config:type="$type">$value</config:config-item>';
    return '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<office:document-settings xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" '
        'xmlns:config="urn:oasis:names:tc:opendocument:xmlns:config:1.0" office:version="1.3">'
        '<office:settings><config:config-item-set config:name="ooo:view-settings">'
        '<config:config-item-map-indexed config:name="Views"><config:config-item-map-entry>'
        '${item('ViewId', 'string', 'view1')}'
        '<config:config-item-map-named config:name="Tables">'
        '<config:config-item-map-entry config:name="${_escape(sheetName)}">'
        '${item('CursorPositionX', 'int', cols)}${item('CursorPositionY', 'int', rows)}'
        '${item('HorizontalSplitMode', 'short', 2)}${item('VerticalSplitMode', 'short', 2)}'
        '${item('HorizontalSplitPosition', 'int', cols)}${item('VerticalSplitPosition', 'int', rows)}'
        '${item('ActiveSplitRange', 'short', 2)}'
        '${item('PositionLeft', 'int', 0)}${item('PositionRight', 'int', cols)}'
        '${item('PositionTop', 'int', 0)}${item('PositionBottom', 'int', rows)}'
        '</config:config-item-map-entry></config:config-item-map-named>'
        '${item('ActiveTable', 'string', _escape(sheetName))}'
        '</config:config-item-map-entry></config:config-item-map-indexed>'
        '</config:config-item-set></office:settings></office:document-settings>';
  }

  static String _rgb(int argb) =>
      '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  static String _pt(double size) => size == size.truncateToDouble()
      ? size.toInt().toString()
      : size.toString();

  static String _escape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

final class _CellStyle {
  const _CellStyle(this.fill, this.font, this.right);

  final int fill;
  final ExportFont font;
  final bool right;

  @override
  bool operator ==(Object other) =>
      other is _CellStyle &&
      other.fill == fill &&
      other.font == font &&
      other.right == right;

  @override
  int get hashCode => Object.hash(fill, font, right);
}
