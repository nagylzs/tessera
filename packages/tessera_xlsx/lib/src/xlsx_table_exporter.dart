import 'dart:typed_data';

import 'package:tessera/tessera.dart';

import 'xlsx_writer.dart';

/// One column of a table for [XlsxTableExporter]: its [header], an Excel
/// number [format] code for its numbers and dates (`#,##0.00`,
/// `#,##0 "Ft"`, `yyyy.mm.dd`; `null` for the exporter's defaults) and a
/// fixed [width] in characters (`null`: sized to the content).
final class XlsxColumn {
  const XlsxColumn(this.header, {this.format, this.width});

  final String header;
  final String? format;
  final double? width;
}

/// Writes plain rows — not a cube — as a worksheet that is a filterable
/// data table: a bold header row with an autofilter over the whole range,
/// the header frozen, real numbers, booleans and dates, content-sized
/// columns. What an app hands over when the user wants "the grid in
/// Excel" rather than a pivot ([XlsxCubeExporter]).
///
/// A row is a list of cell values in column order: `num` (a numeric cell
/// in the column's format), `bool`, `DateTime` (an Excel date: the
/// column's format, else [dateFormat], or [dateTimeFormat] for a value
/// with a time of day), `null` (an empty cell) and anything else as text
/// (`toString()`). A row shorter than the columns leaves the rest empty.
///
/// [exportFacts] does the same for a [FactTable], with the column labels as
/// headers.
final class XlsxTableExporter {
  const XlsxTableExporter({
    this.headerFill = 0xFFD9E1F2,
    this.headerFont = const ExportFont(bold: true),
    this.font = const ExportFont(),
    this.numberFormat = 'General',
    this.dateFormat = 'yyyy-mm-dd',
    this.dateTimeFormat = 'yyyy-mm-dd hh:mm',
    this.autoFilter = true,
    this.freezeHeader = true,
    this.borders = false,
    this.borderColor = 0xFFBFBFBF,
    this.minColumnWidth = 6,
    this.maxColumnWidth = 60,
  });

  /// The header row's fill (ARGB; `null` for none) and font.
  final int? headerFill;
  final ExportFont headerFont;

  /// The data cells' font.
  final ExportFont font;

  /// The Excel format of a number in a column without a format of its own.
  final String numberFormat;

  /// The Excel formats of a date without and with a time of day, in a
  /// column without a format of its own.
  final String dateFormat;
  final String dateTimeFormat;

  /// An autofilter on the header row over the whole table.
  final bool autoFilter;

  /// The header row stays visible while scrolling.
  final bool freezeHeader;

  /// Thin borders around every cell, in [borderColor].
  final bool borders;
  final int borderColor;

  /// Bounds of the content-sized column widths, in characters.
  final double minColumnWidth;
  final double maxColumnWidth;

  /// The workbook bytes of [rows] under [columns]. [sheetName] is trimmed
  /// to Excel's rules (31 characters, no `[]:*?/\`).
  Uint8List export(
    List<XlsxColumn> columns,
    Iterable<List<Object?>> rows, {
    String sheetName = 'Data',
  }) {
    final writer = XlsxWriter(
      sheetName: _sheetName(sheetName),
      numberFormat: numberFormat,
      borderColor: borderColor,
    );
    final header = writer.style(headerFill, font: headerFont, border: borders);
    // Per column: text, number, date and date-time styles.
    final text = <int>[], number = <int>[], date = <int>[], dateTime = <int>[];
    final longest = <int>[];
    for (var c = 0; c < columns.length; c++) {
      final col = columns[c];
      text.add(writer.style(null, font: font, border: borders));
      number.add(
        writer.style(
          null,
          font: font,
          border: borders,
          right: true,
          format: col.format ?? numberFormat,
        ),
      );
      date.add(
        writer.style(
          null,
          font: font,
          border: borders,
          format: col.format ?? dateFormat,
        ),
      );
      dateTime.add(
        writer.style(
          null,
          font: font,
          border: borders,
          format: col.format ?? dateTimeFormat,
        ),
      );
      writer.cell(0, c, col.header, header);
      longest.add(col.header.length + 2); // room for the filter button
    }
    var r = 0;
    for (final row in rows) {
      r++;
      for (var c = 0; c < columns.length; c++) {
        final value = c < row.length ? row[c] : null;
        switch (value) {
          case null:
            continue;
          case num():
            writer.cell(r, c, value, number[c]);
          case DateTime v:
            final timed =
                v.hour != 0 ||
                v.minute != 0 ||
                v.second != 0 ||
                v.millisecond != 0;
            writer.dateCell(r, c, v, timed ? dateTime[c] : date[c]);
          case bool():
            writer.cell(r, c, value, text[c]);
          default:
            writer.cell(r, c, value.toString(), text[c]);
        }
        final n = _displayLength(value, columns[c]);
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

  /// Every fact of [facts] (or the [columns] named, in that order), the
  /// columns' labels as headers, [formats] by column name.
  Uint8List exportFacts(
    FactTable facts, {
    List<String>? columns,
    Map<String, String> formats = const {},
    String sheetName = 'Data',
  }) {
    final names = columns ?? [for (final c in facts.columns) c.name];
    return export(
      [
        for (final n in names)
          XlsxColumn(facts.column(n).label, format: formats[n]),
      ],
      [
        for (var row = 0; row < facts.rowCount; row++)
          [for (final n in names) facts.valueAt(row, n)],
      ],
      sheetName: sheetName,
    );
  }

  /// The Excel serial number of [value] in the 1900 date system: whole
  /// days since 1899-12-30, the time of day as the fraction; the
  /// wall-clock fields are used as they are, without a time zone
  /// conversion.
  static num excelSerialOf(DateTime value) => XlsxWriter.excelSerial(value);

  /// About how many characters the cell shows, for the column width.
  static int _displayLength(Object? value, XlsxColumn column) =>
      switch (value) {
        null => 0,
        DateTime() => (column.format ?? 'yyyy-mm-dd hh:mm').length,
        num v => v.toString().length + 3, // grouping and a currency suffix
        _ => value.toString().length,
      };

  static String _sheetName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[\[\]:*?/\\]'), ' ').trim();
    final short = cleaned.length > 31 ? cleaned.substring(0, 31) : cleaned;
    return short.isEmpty ? 'Data' : short;
  }
}
