import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:tessera/tessera.dart';

/// A minimal `.xlsx` package writer: one worksheet, shared strings, a
/// style registry (fills, bold, alignment, one number format, thin
/// borders), merged cells, column widths and frozen panes. Internal to
/// `XlsxCubeExporter`; knows nothing about cubes.
final class XlsxWriter {
  XlsxWriter({
    required this.sheetName,
    required this.numberFormat,
    required this.borderColor,
  });

  final String sheetName;
  final String numberFormat;
  final int borderColor;

  final _sharedStrings = <String>[];
  final _sharedIndex = <String, int>{};
  final _fills = <int>[];
  final _fonts = <ExportFont>[];
  final _styles = <_Xf>[];
  final _styleIndex = <_Xf, int>{};
  final _rows = <int, StringBuffer>{};
  final _merges = <String>[];
  final _widths = <int, double>{};
  int _lastRow = 0, _lastColumn = 0;
  ({int rows, int columns})? _freeze;

  /// Style index for a cell with [fill] (ARGB) and [font], right- or
  /// left-aligned; registered on first use.
  int style(
    int fill, {
    ExportFont font = const ExportFont(),
    bool right = false,
  }) {
    var fillId = _fills.indexOf(fill);
    if (fillId < 0) {
      _fills.add(fill);
      fillId = _fills.length - 1;
    }
    var fontId = _fonts.indexOf(font);
    if (fontId < 0) {
      _fonts.add(font);
      fontId = _fonts.length - 1;
    }
    final xf = _Xf(fillId, fontId, right);
    return _styleIndex.putIfAbsent(xf, () {
      _styles.add(xf);
      return _styles.length - 1;
    });
  }

  /// Writes [value] at 0-based ([row], [column]): numbers as numeric
  /// cells, booleans as boolean cells, anything else as a shared string;
  /// `null` gives a styled empty cell.
  void cell(int row, int column, Object? value, int styleIndex) {
    final ref = cellRef(row, column);
    final style = styleIndex + 1; // cellXfs 0 is the default xf
    final out = _rows.putIfAbsent(row, StringBuffer.new);
    switch (value) {
      case null:
        out.write('<c r="$ref" s="$style"/>');
      case num v when v.isFinite:
        out.write('<c r="$ref" s="$style"><v>$v</v></c>');
      case num():
        out.write('<c r="$ref" s="$style"/>');
      case bool v:
        out.write('<c r="$ref" s="$style" t="b"><v>${v ? 1 : 0}</v></c>');
      default:
        final s = value is DateTime
            ? value.toIso8601String()
            : value.toString();
        final i = _sharedIndex.putIfAbsent(s, () {
          _sharedStrings.add(s);
          return _sharedStrings.length - 1;
        });
        out.write('<c r="$ref" s="$style" t="s"><v>$i</v></c>');
    }
    if (row > _lastRow) _lastRow = row;
    if (column > _lastColumn) _lastColumn = column;
  }

  /// Merges the rectangle from ([row], [column]) spanning [rowSpan] ×
  /// [columnSpan] cells (no-op for a single cell).
  void merge(int row, int column, int rowSpan, int columnSpan) {
    if (rowSpan <= 1 && columnSpan <= 1) return;
    _merges.add(
      '${cellRef(row, column)}:'
      '${cellRef(row + rowSpan - 1, column + columnSpan - 1)}',
    );
  }

  /// Width of [column] in characters.
  void columnWidth(int column, double width) => _widths[column] = width;

  /// Keeps the first [rows] rows and [columns] columns visible.
  void freeze({required int rows, required int columns}) =>
      _freeze = (rows: rows, columns: columns);

  Uint8List build() {
    final archive = Archive();
    void add(String path, String xml) => archive.add(
      ArchiveFile.string(
        path,
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n$xml',
      ),
    );
    add('[Content_Types].xml', _contentTypes);
    add('_rels/.rels', _rootRels);
    add('xl/workbook.xml', _workbook());
    add('xl/_rels/workbook.xml.rels', _workbookRels);
    add('xl/styles.xml', _stylesXml());
    add('xl/sharedStrings.xml', _sharedStringsXml());
    add('xl/worksheets/sheet1.xml', _sheetXml());
    return ZipEncoder().encodeBytes(archive);
  }

  static String cellRef(int row, int column) =>
      '${columnLetters(column)}${row + 1}';

  static String columnLetters(int index) {
    var n = index + 1;
    final out = <int>[];
    while (n > 0) {
      n--;
      out.insert(0, 0x41 + n % 26);
      n ~/= 26;
    }
    return String.fromCharCodes(out);
  }

  static String escape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  static String _argb(int color) =>
      color.toUnsigned(32).toRadixString(16).toUpperCase().padLeft(8, '0');

  static const _ns =
      'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
  static const _rns =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';

  static const _contentTypes =
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
      '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
      '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
      '<Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>'
      '</Types>';

  static const _rootRels =
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
      '</Relationships>';

  static const _workbookRels =
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
      '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
      '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>'
      '</Relationships>';

  String _workbook() =>
      '<workbook xmlns="$_ns" xmlns:r="$_rns"><sheets>'
      '<sheet name="${escape(sheetName)}" sheetId="1" r:id="rId1"/>'
      '</sheets></workbook>';

  String _stylesXml() {
    final b = StringBuffer('<styleSheet xmlns="$_ns">');
    b.write(
      '<numFmts count="1"><numFmt numFmtId="164" formatCode="${escape(numberFormat)}"/></numFmts>',
    );
    // font 0 is the workbook default; the registered ones follow
    b.write('<fonts count="${_fonts.length + 1}">');
    b.write('<font><sz val="10"/><name val="Arial"/></font>');
    for (final f in _fonts) {
      b.write(
        '<font>${f.bold ? '<b/>' : ''}${f.italic ? '<i/>' : ''}'
        '<sz val="${f.size == f.size.truncateToDouble() ? f.size.toInt() : f.size}"/>'
        '<color rgb="${_argb(f.color)}"/>'
        '<name val="${escape(f.family)}"/></font>',
      );
    }
    b.write('</fonts>');
    // fill 0 (none) and 1 (gray125) are reserved by Excel
    b.write('<fills count="${_fills.length + 2}">');
    b.write('<fill><patternFill patternType="none"/></fill>');
    b.write('<fill><patternFill patternType="gray125"/></fill>');
    for (final f in _fills) {
      b.write(
        '<fill><patternFill patternType="solid"><fgColor rgb="${_argb(f)}"/>'
        '<bgColor indexed="64"/></patternFill></fill>',
      );
    }
    b.write('</fills>');
    final side = '<color rgb="${_argb(borderColor)}"/>';
    b.write(
      '<borders count="2"><border><left/><right/><top/><bottom/><diagonal/></border>'
      '<border><left style="thin">$side</left><right style="thin">$side</right>'
      '<top style="thin">$side</top><bottom style="thin">$side</bottom><diagonal/></border></borders>',
    );
    b.write(
      '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>',
    );
    b.write('<cellXfs count="${_styles.length + 1}">');
    b.write('<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>');
    for (final s in _styles) {
      b.write(
        '<xf numFmtId="164" fontId="${s.fontId + 1}" fillId="${s.fillId + 2}" '
        'borderId="1" xfId="0" applyNumberFormat="1" applyFont="1" applyFill="1" '
        'applyBorder="1" applyAlignment="1">'
        '<alignment horizontal="${s.right ? 'right' : 'left'}" vertical="center"/></xf>',
      );
    }
    b.write('</cellXfs>');
    b.write(
      '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>',
    );
    b.write('</styleSheet>');
    return b.toString();
  }

  String _sharedStringsXml() {
    final b = StringBuffer(
      '<sst xmlns="$_ns" count="${_sharedStrings.length}" uniqueCount="${_sharedStrings.length}">',
    );
    for (final s in _sharedStrings) {
      b.write('<si><t xml:space="preserve">${escape(s)}</t></si>');
    }
    b.write('</sst>');
    return b.toString();
  }

  String _sheetXml() {
    final b = StringBuffer('<worksheet xmlns="$_ns" xmlns:r="$_rns">');
    b.write('<dimension ref="A1:${cellRef(_lastRow, _lastColumn)}"/>');
    final freeze = _freeze;
    b.write('<sheetViews><sheetView workbookViewId="0">');
    if (freeze != null && (freeze.rows > 0 || freeze.columns > 0)) {
      b.write(
        '<pane xSplit="${freeze.columns}" ySplit="${freeze.rows}" '
        'topLeftCell="${cellRef(freeze.rows, freeze.columns)}" '
        'activePane="bottomRight" state="frozen"/>',
      );
    }
    b.write('</sheetView></sheetViews>');
    b.write('<sheetFormatPr defaultRowHeight="15"/>');
    if (_widths.isNotEmpty) {
      b.write('<cols>');
      for (final e
          in (_widths.entries.toList()..sort((a, b) => a.key - b.key))) {
        b.write(
          '<col min="${e.key + 1}" max="${e.key + 1}" width="${e.value}" customWidth="1"/>',
        );
      }
      b.write('</cols>');
    }
    b.write('<sheetData>');
    for (var r = 0; r <= _lastRow; r++) {
      final cells = _rows[r];
      if (cells == null) continue;
      b.write('<row r="${r + 1}">');
      b.write(cells);
      b.write('</row>');
    }
    b.write('</sheetData>');
    if (_merges.isNotEmpty) {
      b.write('<mergeCells count="${_merges.length}">');
      for (final m in _merges) {
        b.write('<mergeCell ref="$m"/>');
      }
      b.write('</mergeCells>');
    }
    b.write('</worksheet>');
    return b.toString();
  }
}

final class _Xf {
  const _Xf(this.fillId, this.fontId, this.right);

  final int fillId;
  final int fontId;
  final bool right;

  @override
  bool operator ==(Object other) =>
      other is _Xf &&
      other.fillId == fillId &&
      other.fontId == fontId &&
      other.right == right;

  @override
  int get hashCode => Object.hash(fillId, fontId, right);
}
