import 'dart:typed_data';

import 'package:tessera/tessera.dart';

import 'xlsx_cube_exporter.dart';
import 'xlsx_writer.dart';

/// Writes an [ExportTable] — plain rows or a fact table
/// ([ExportTable.ofFacts]) — as a worksheet that is a filterable data
/// table rather than a pivot ([XlsxCubeExporter]): a header row with an
/// autofilter over the whole range, the header frozen, real numbers,
/// booleans and dates, content-sized columns. What an app hands over when
/// the user wants "the grid in Excel".
///
/// Numbers take the column's [ExportColumn.numberFormat] (as an Excel code,
/// see [XlsxCubeExporter.formatCode]), else [numberFormatCode]; a
/// `DateTime` is an Excel date in [dateFormat] or [dateTimeFormat]
/// ([ExportColumn.showsTime]); [formatCodes] overrides both per column with
/// a native Excel code. Dates before 1900, which Excel cannot show, are
/// written as ISO 8601 text.
///
/// Excel's limits apply: 16 384 columns and 1 048 576 rows including the
/// header — beyond them [export] throws an [ArgumentError] — and 32 767
/// characters per cell, beyond which a text is cut. Characters XML does not
/// allow (most control characters) are dropped from the text.
final class XlsxTableExporter {
  const XlsxTableExporter({
    this.theme = const TableExportTheme(),
    this.numberFormatCode = 'General',
    this.dateFormat = 'yyyy-mm-dd',
    this.dateTimeFormat = 'yyyy-mm-dd hh:mm',
    this.formatCodes = const {},
    this.autoFilter = true,
    this.freezeHeader = true,
    this.minColumnWidth = 6,
    this.maxColumnWidth = 60,
  });

  /// Header fill and font, the data font and the borders; shared with the
  /// other table exporters.
  final TableExportTheme theme;

  /// The Excel code of a number in a column without a
  /// [ExportColumn.numberFormat]: `General` shows it as it is.
  final String numberFormatCode;

  /// The Excel codes of a date without and with its time of day.
  final String dateFormat;
  final String dateTimeFormat;

  /// Native Excel codes (`#,##0 "Ft"`, `yyyy.mm.dd`) by
  /// [ExportColumn.key], for the numbers and dates of that column; they win
  /// over everything above.
  final Map<String, String> formatCodes;

  /// An autofilter on the header row over the whole table.
  final bool autoFilter;

  /// The header row stays visible while scrolling.
  final bool freezeHeader;

  /// Bounds of the content-sized column widths, in characters.
  final double minColumnWidth;
  final double maxColumnWidth;

  /// Excel's sheet size.
  static const maxRows = 1048576, maxColumns = 16384;

  /// Excel's longest cell text.
  static const maxTextLength = 32767;

  /// The workbook bytes of [table]. [sheetName] is trimmed to Excel's rules
  /// (31 characters, no `[]:*?/\`).
  Uint8List export(ExportTable table, {String sheetName = 'Data'}) {
    final columns = table.columns;
    if (columns.length > maxColumns) {
      throw ArgumentError(
        'The table has ${columns.length} columns, a worksheet $maxColumns.',
      );
    }
    final writer = XlsxWriter(
      sheetName: _sheetName(sheetName),
      numberFormat: numberFormatCode,
      borderColor: theme.borderColor,
    );
    final borders = theme.borders;
    final header = writer.style(
      theme.headerFill,
      font: theme.headerFont,
      border: borders,
    );
    // Per column: text, number, date and date-time styles.
    final text = <int>[], number = <int>[], date = <int>[], dateTime = <int>[];
    final longest = <int>[];
    for (var c = 0; c < columns.length; c++) {
      final col = columns[c];
      final code = formatCodes[col.key];
      final numberFormat = col.numberFormat;
      int style(String format, {bool right = false}) => writer.style(
        null,
        font: theme.font,
        border: borders,
        right: right,
        format: format,
      );
      text.add(writer.style(null, font: theme.font, border: borders));
      number.add(
        style(
          code ??
              (numberFormat == null
                  ? numberFormatCode
                  : XlsxCubeExporter.formatCode(numberFormat)),
          right: true,
        ),
      );
      date.add(style(code ?? dateFormat));
      dateTime.add(style(code ?? dateTimeFormat));
      writer.cell(0, c, _cut(col.header), header);
      longest.add(col.header.length + 2); // room for the filter button
    }
    var r = 0;
    for (final row in table.rows) {
      if (++r >= maxRows) {
        throw ArgumentError(
          'The table has more than the ${maxRows - 1} rows a worksheet '
          'holds under its header.',
        );
      }
      for (var c = 0; c < columns.length; c++) {
        final value = c < row.length ? row[c] : null;
        final int n;
        switch (value) {
          case null:
            continue;
          case num v:
            writer.cell(r, c, v, number[c]);
            n = _numberLength(v, columns[c]);
          case DateTime v:
            final timed = columns[c].showsTime(v);
            writer.dateCell(r, c, v, timed ? dateTime[c] : date[c]);
            n =
                (formatCodes[columns[c].key] ??
                        (timed ? dateTimeFormat : dateFormat))
                    .length;
          case bool v:
            writer.cell(r, c, v, text[c]);
            n = 5;
          default:
            final s = _cut(value.toString());
            writer.cell(r, c, s, text[c]);
            n = _longestLine(s);
        }
        if (n > longest[c]) longest[c] = n;
      }
    }
    for (var c = 0; c < columns.length; c++) {
      writer.columnWidth(
        c,
        columns[c].width ??
            (longest[c] * 1.1 + 1).clamp(minColumnWidth, maxColumnWidth),
      );
    }
    if (freezeHeader) writer.freeze(rows: 1, columns: 0);
    if (autoFilter && columns.isNotEmpty) {
      writer.autoFilter(0, 0, r + 1, columns.length);
    }
    return writer.build();
  }

  static String _cut(String s) =>
      s.length > maxTextLength ? s.substring(0, maxTextLength) : s;

  /// About how many characters a number shows, with grouping.
  static int _numberLength(num v, ExportColumn column) {
    final f = column.numberFormat;
    final digits = f == null
        ? v.toString().length
        : v.abs().truncate().toString().length +
              (f.decimals > 0 ? f.decimals + 1 : 0) +
              (v < 0 ? 1 : 0);
    return digits + digits ~/ 3;
  }

  static int _longestLine(String s) {
    if (!s.contains('\n')) return s.length;
    var max = 0;
    for (final line in s.split('\n')) {
      if (line.length > max) max = line.length;
    }
    return max;
  }

  static String _sheetName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[\[\]:*?/\\]'), ' ').trim();
    final short = cleaned.length > 31 ? cleaned.substring(0, 31) : cleaned;
    return short.isEmpty ? 'Data' : short;
  }
}
