import 'csv_cube_exporter.dart';
import 'export_table.dart';

/// Writes an [ExportTable] — plain rows or a fact table
/// ([ExportTable.ofFacts]) — as CSV: a header row, then one line per row.
///
/// The text is data, not a display: numbers are written plainly with the
/// [CsvExportOptions.decimalSeparator] (no grouping, [ExportColumn.numberFormat]
/// is not applied), booleans as `true` / `false`, a calendar day as
/// `yyyy-MM-dd` and a point in time as full ISO 8601 (see
/// [ExportColumn.showsTime]) — what `CsvDataSource` and type inference read
/// back with the same types. [CsvExportOptions.groupLabels] does not apply.
final class CsvTableExporter {
  const CsvTableExporter({
    this.options = const CsvExportOptions(),
    this.header = true,
  });

  final CsvExportOptions options;

  /// Write the header row.
  final bool header;

  /// The CSV text.
  String export(ExportTable table) {
    final out = StringBuffer();
    writeTo(out, table);
    return out.toString();
  }

  /// Like [export], into [sink] (a file's `IOSink`, a `StringBuffer`), one
  /// row at a time.
  void writeTo(StringSink sink, ExportTable table) {
    final columns = table.columns;
    if (options.byteOrderMark) sink.write('﻿');
    if (header) {
      for (var c = 0; c < columns.length; c++) {
        if (c > 0) sink.write(options.delimiter);
        sink.write(options.field(columns[c].header));
      }
      sink.write(options.lineEnding);
    }
    for (final row in table.rows) {
      for (var c = 0; c < columns.length; c++) {
        if (c > 0) sink.write(options.delimiter);
        final value = c < row.length ? row[c] : null;
        sink.write(options.field(_text(value, columns[c])));
      }
      sink.write(options.lineEnding);
    }
  }

  String _text(Object? value, ExportColumn column) => switch (value) {
    null => '',
    final num v when !v.isFinite => '',
    final num v => CsvCubeExporter.formatNumber(v, options.decimalSeparator),
    final bool v => v.toString(),
    final DateTime v => column.showsTime(v) ? v.toIso8601String() : _day(v),
    final v => v.toString(),
  };

  static String _day(DateTime v) =>
      '${v.year.toString().padLeft(4, '0')}-'
      '${v.month.toString().padLeft(2, '0')}-'
      '${v.day.toString().padLeft(2, '0')}';
}
