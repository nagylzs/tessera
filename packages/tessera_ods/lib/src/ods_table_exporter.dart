import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:tessera/tessera.dart';

import 'ods_cube_exporter.dart';
import 'ods_parts.dart';

/// Writes an [ExportTable] — plain rows or a fact table
/// ([ExportTable.ofFacts]) — as an OpenDocument sheet that is a filterable
/// data table rather than a pivot ([OdsCubeExporter]): a header row with
/// autofilter buttons over the whole range (an anonymous database range,
/// what LibreOffice writes), the header frozen and repeated on printed
/// pages, real numbers, booleans and dates, content-sized columns.
///
/// Numbers take the column's [ExportColumn.numberFormat], else they are
/// shown as they are; a `DateTime` is a date shown as `YYYY-MM-DD`, with
/// ` HH:MM` when [ExportColumn.showsTime]. Line breaks, tabs and runs of
/// spaces in a text are kept; characters XML does not allow are dropped.
/// The format has no size limit, but LibreOffice opens at most 1 048 576
/// rows and 16 384 columns.
final class OdsTableExporter {
  const OdsTableExporter({
    this.theme = const TableExportTheme(),
    this.autoFilter = true,
    this.freezeHeader = true,
    this.minColumnWidth = 6,
    this.maxColumnWidth = 60,
  });

  /// Header fill and font, the data font and the borders; shared with the
  /// other table exporters.
  final TableExportTheme theme;

  /// Filter buttons on the header row over the whole table.
  final bool autoFilter;

  /// The header row stays visible while scrolling (a view setting in
  /// `settings.xml`).
  final bool freezeHeader;

  /// Bounds of the content-sized column widths, in characters.
  final double minColumnWidth;
  final double maxColumnWidth;

  /// The document bytes of [table].
  Uint8List export(ExportTable table, {String sheetName = 'Data'}) =>
      _Writer(this, table, sheetName.isEmpty ? 'Data' : sheetName).build();
}

/// What a cell shows its value as.
enum _Kind { text, number, date, dateTime }

final class _Writer {
  _Writer(this.exporter, this.table, this.sheetName);

  final OdsTableExporter exporter;
  final ExportTable table;
  final String sheetName;

  TableExportTheme get theme => exporter.theme;
  List<ExportColumn> get columns => table.columns;

  final _numberFormats = <NumberFormat>[];
  final _styles = <_CellStyle>[];
  final _styleIndex = <_CellStyle, int>{};
  late final List<int> _longest = [
    for (final c in columns) c.header.length + 2, // the filter button
  ];
  int _rowCount = 0;

  Uint8List build() {
    final rows = _rows(); // registers styles
    final archive = Archive();
    archive.add(
      ArchiveFile.string('mimetype', odsMimeType)
        ..compression = CompressionType.none,
    );
    archive.add(
      ArchiveFile.string(
        'META-INF/manifest.xml',
        odsManifest(withSettings: exporter.freezeHeader),
      ),
    );
    archive.add(ArchiveFile.string('content.xml', _content(rows)));
    archive.add(ArchiveFile.string('styles.xml', odsStylesXml));
    if (exporter.freezeHeader) {
      archive.add(
        ArchiveFile.string(
          'settings.xml',
          odsFreezeSettings(sheetName, rows: 1),
        ),
      );
    }
    return ZipEncoder().encodeBytes(archive);
  }

  int _style(_CellStyle style) => _styleIndex.putIfAbsent(style, () {
    _styles.add(style);
    return _styles.length - 1;
  });

  String _rows() {
    final b = StringBuffer();
    final header = _style(
      _CellStyle(theme.headerFill, theme.headerFont, false, null),
    );
    // Per column: the style of each kind of value.
    final styles = [
      for (final col in columns)
        {
          for (final kind in _Kind.values)
            kind: _style(_styleFor(kind, col.numberFormat)),
        },
    ];
    b.write('<table:table-header-rows><table:table-row>');
    for (final col in columns) {
      b.write(
        '<table:table-cell table:style-name="ce$header" '
        'office:value-type="string">${_paragraphs(col.header)}'
        '</table:table-cell>',
      );
    }
    b.write('</table:table-row></table:table-header-rows>');
    for (final row in table.rows) {
      _rowCount++;
      b.write('<table:table-row>');
      for (var c = 0; c < columns.length; c++) {
        final value = c < row.length ? row[c] : null;
        final col = columns[c];
        final String shown;
        switch (value) {
          case null:
            b.write(
              '<table:table-cell table:style-name="ce${styles[c][_Kind.text]}"/>',
            );
            continue;
          case num v when !v.isFinite:
            b.write(
              '<table:table-cell table:style-name="ce${styles[c][_Kind.number]}"/>',
            );
            continue;
          case num v:
            final nf = col.numberFormat;
            shown = nf == null
                ? CsvCubeExporter.formatNumber(v, '.')
                : v.toStringAsFixed(nf.decimals);
            b.write(
              '<table:table-cell table:style-name="ce${styles[c][_Kind.number]}" '
              'office:value-type="float" office:value="$v">',
            );
          case bool v:
            shown = v ? 'TRUE' : 'FALSE';
            b.write(
              '<table:table-cell table:style-name="ce${styles[c][_Kind.text]}" '
              'office:value-type="boolean" office:boolean-value="$v">',
            );
          case DateTime v:
            final timed = col.showsTime(v);
            final day = _day(v);
            final time =
                '${_two(v.hour)}:${_two(v.minute)}:${_two(v.second)}'
                '${v.millisecond == 0 ? '' : '.${v.millisecond.toString().padLeft(3, '0')}'}';
            shown = timed ? '$day ${_two(v.hour)}:${_two(v.minute)}' : day;
            b.write(
              '<table:table-cell table:style-name="ce${styles[c][timed ? _Kind.dateTime : _Kind.date]}" '
              'office:value-type="date" office:date-value="${timed ? '${day}T$time' : day}">',
            );
          default:
            shown = value.toString();
            b.write(
              '<table:table-cell table:style-name="ce${styles[c][_Kind.text]}" '
              'office:value-type="string">',
            );
        }
        b.write('${_paragraphs(shown)}</table:table-cell>');
        final n = _longestLine(shown);
        if (n > _longest[c]) _longest[c] = n;
      }
      b.write('</table:table-row>');
    }
    return b.toString();
  }

  _CellStyle _styleFor(_Kind kind, NumberFormat? numberFormat) {
    final String? data;
    switch (kind) {
      case _Kind.text:
        data = null;
      case _Kind.number:
        if (numberFormat == null) {
          data = null;
        } else {
          var i = _numberFormats.indexOf(numberFormat);
          if (i < 0) {
            _numberFormats.add(numberFormat);
            i = _numberFormats.length - 1;
          }
          data = 'N$i';
        }
      case _Kind.date:
        data = 'D0';
      case _Kind.dateTime:
        data = 'D1';
    }
    return _CellStyle(null, theme.font, kind == _Kind.number, data);
  }

  String _content(String rows) {
    final b = StringBuffer(odsContentStart);
    b.write('<office:font-face-decls>');
    for (final f in {theme.headerFont.family, theme.font.family}) {
      b.write(
        '<style:font-face style:name="${odsEscape(f)}" svg:font-family="${odsEscape(f)}"/>',
      );
    }
    b.write('</office:font-face-decls>');
    b.write('<office:automatic-styles>');
    for (var i = 0; i < _numberFormats.length; i++) {
      final nf = _numberFormats[i];
      b.write(
        '<number:number-style style:name="N$i"><number:number '
        'number:decimal-places="${nf.decimals}" number:min-decimal-places="${nf.decimals}" '
        'number:min-integer-digits="1"${nf.grouping ? ' number:grouping="true"' : ''}/>'
        '</number:number-style>',
      );
    }
    const dash = '<number:text>-</number:text>';
    const day =
        '<number:year number:style="long"/>$dash'
        '<number:month number:style="long"/>$dash'
        '<number:day number:style="long"/>';
    b.write('<number:date-style style:name="D0">$day</number:date-style>');
    b.write(
      '<number:date-style style:name="D1">$day<number:text> </number:text>'
      '<number:hours number:style="long"/><number:text>:</number:text>'
      '<number:minutes number:style="long"/></number:date-style>',
    );
    for (var c = 0; c < columns.length; c++) {
      final chars =
          columns[c].width ??
          (_longest[c] * 1.1 + 1).clamp(
            exporter.minColumnWidth,
            exporter.maxColumnWidth,
          );
      b.write(
        '<style:style style:name="co$c" style:family="table-column">'
        '<style:table-column-properties style:column-width="${(chars * 0.2).toStringAsFixed(2)}cm"/>'
        '</style:style>',
      );
    }
    final border = theme.borders
        ? ' fo:border="0.5pt solid ${odsRgb(theme.borderColor)}"'
        : '';
    for (var i = 0; i < _styles.length; i++) {
      final s = _styles[i];
      final fill = s.fill;
      b.write(
        '<style:style style:name="ce$i" style:family="table-cell"'
        '${s.data == null ? '' : ' style:data-style-name="${s.data}"'}>'
        '<style:table-cell-properties'
        '${fill == null ? '' : ' fo:background-color="${odsRgb(fill)}"'}'
        '$border/>'
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
    final name = odsEscape(sheetName);
    b.write('<table:table table:name="$name">');
    for (var c = 0; c < columns.length; c++) {
      b.write('<table:table-column table:style-name="co$c"/>');
    }
    b.write(rows);
    b.write('</table:table>');
    if (exporter.autoFilter && columns.isNotEmpty) {
      final quoted = odsEscape("'${sheetName.replaceAll("'", "''")}'");
      final last = '${_columnName(columns.length - 1)}${_rowCount + 1}';
      b.write(
        '<table:database-ranges><table:database-range '
        'table:name="__Anonymous_Sheet_DB__0" '
        'table:target-range-address="$quoted.A1:$quoted.$last" '
        'table:display-filter-buttons="true"/></table:database-ranges>',
      );
    }
    b.write('</office:spreadsheet></office:body>');
    b.write('</office:document-content>');
    return b.toString();
  }

  /// [text] as `text:p` paragraphs, one per line, with tabs and runs of
  /// spaces written so that they survive (XML collapses whitespace).
  static String _paragraphs(String text) {
    final b = StringBuffer();
    for (final line in text.split(RegExp(r'\r\n|\r|\n'))) {
      b.write('<text:p>');
      var i = 0;
      while (i < line.length) {
        if (line[i] == '\t') {
          b.write('<text:tab/>');
          i++;
        } else if (line[i] == ' ') {
          var n = 1;
          while (i + n < line.length && line[i + n] == ' ') {
            n++;
          }
          // inside the line the first space of a run is an ordinary one;
          // leading, trailing and the rest are text:s
          final inside = i > 0 && i + n < line.length;
          if (inside) b.write(' ');
          final extra = inside ? n - 1 : n;
          if (extra == 1) {
            b.write('<text:s/>');
          } else if (extra > 1) {
            b.write('<text:s text:c="$extra"/>');
          }
          i += n;
        } else {
          var j = i;
          while (j < line.length && line[j] != '\t' && line[j] != ' ') {
            j++;
          }
          b.write(odsEscape(line.substring(i, j)));
          i = j;
        }
      }
      b.write('</text:p>');
    }
    return b.toString();
  }

  static int _longestLine(String s) {
    var max = 0;
    for (final line in s.split('\n')) {
      if (line.length > max) max = line.length;
    }
    return max;
  }

  static String _columnName(int column) {
    final out = <int>[];
    for (var c = column + 1; c > 0; c = (c - 1) ~/ 26) {
      out.insert(0, 65 + (c - 1) % 26);
    }
    return String.fromCharCodes(out);
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _day(DateTime v) =>
      '${v.year.toString().padLeft(4, '0')}-${_two(v.month)}-${_two(v.day)}';
}

final class _CellStyle {
  const _CellStyle(this.fill, this.font, this.right, this.data);

  final int? fill;
  final ExportFont font;
  final bool right;

  /// The data style's name (`N0`, `D0`, …); `null` for none.
  final String? data;

  @override
  bool operator ==(Object other) =>
      other is _CellStyle &&
      other.fill == fill &&
      other.font == font &&
      other.right == right &&
      other.data == data;

  @override
  int get hashCode => Object.hash(fill, font, right, data);
}
