import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:tessera/tessera.dart';

import 'ods_parts.dart';

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

  Uint8List build() {
    final rows = _rows(); // registers styles and fonts
    final archive = Archive();
    archive.add(
      ArchiveFile.string('mimetype', odsMimeType)
        ..compression = CompressionType.none,
    );
    archive.add(
      ArchiveFile.string(
        'META-INF/manifest.xml',
        odsManifest(withSettings: exporter.freezeHeaders),
      ),
    );
    archive.add(ArchiveFile.string('content.xml', _content(rows)));
    archive.add(ArchiveFile.string('styles.xml', odsStylesXml));
    if (exporter.freezeHeaders) {
      archive.add(
        ArchiveFile.string(
          'settings.xml',
          odsFreezeSettings(
            sheetName,
            rows: grid.headerRows,
            columns: grid.headerColumns,
          ),
        ),
      );
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
        b.write('<text:p>${odsEscape(text)}</text:p></table:table-cell>');
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
    final b = StringBuffer(odsContentStart);
    b.write('<office:font-face-decls>');
    for (final f in _fonts) {
      b.write(
        '<style:font-face style:name="${odsEscape(f)}" svg:font-family="${odsEscape(f)}"/>',
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
    final border = '0.5pt solid ${odsRgb(theme.borderColor)}';
    for (var i = 0; i < _styles.length; i++) {
      final s = _styles[i];
      b.write(
        '<style:style style:name="ce$i" style:family="table-cell" '
        'style:data-style-name="N1">'
        '<style:table-cell-properties fo:background-color="${odsRgb(s.fill)}" '
        'fo:border="$border" style:vertical-align="middle"/>'
        '<style:paragraph-properties fo:text-align="${s.right ? 'end' : 'start'}"/>'
        '<style:text-properties style:font-name="${odsEscape(s.font.family)}" '
        'fo:font-size="${odsPt(s.font.size)}pt" fo:color="${odsRgb(s.font.color)}"'
        '${s.font.bold ? ' fo:font-weight="bold"' : ''}'
        '${s.font.italic ? ' fo:font-style="italic"' : ''}/>'
        '</style:style>',
      );
    }
    b.write('</office:automatic-styles>');
    b.write('<office:body><office:spreadsheet>');
    b.write('<table:table table:name="${odsEscape(sheetName)}">');
    for (var c = 0; c < grid.columnCount; c++) {
      b.write('<table:table-column table:style-name="co$c"/>');
    }
    b.write(rows);
    b.write('</table:table></office:spreadsheet></office:body>');
    b.write('</office:document-content>');
    return b.toString();
  }
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
