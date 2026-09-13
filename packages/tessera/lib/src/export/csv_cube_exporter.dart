import '../cube/aggregate.dart';
import '../cube/cube_layout.dart';
import '../l10n/l10n_en.dart';
import '../l10n/tessera_strings.dart';
import 'cube_grid.dart';

/// How merged header areas are written to a flat CSV.
enum CsvGroupLabels {
  /// The label once, in the area's first cell; the rest of the area blank —
  /// what the sheet looks like.
  origin,

  /// The label repeated in every cell of the area, so each row carries its
  /// full group path — for feeding the file to another tool.
  repeat,
}

/// Separators and formats of a CSV export.
final class CsvExportOptions {
  const CsvExportOptions({
    this.delimiter = ',',
    this.quote = '"',
    this.lineEnding = '\r\n',
    this.decimalSeparator = '.',
    this.groupLabels = CsvGroupLabels.origin,
    this.byteOrderMark = false,
  }) : assert(delimiter.length == 1, 'delimiter must be one character'),
       assert(quote.length == 1, 'quote must be one character'),
       assert(
         decimalSeparator.length == 1,
         'decimalSeparator must be one character',
       );

  /// Field separator; `;` with a `,` [decimalSeparator] suits Excel in
  /// many European locales, `\t` gives TSV.
  final String delimiter;

  final String quote;

  /// RFC 4180 says `\r\n`; `\n` is common on Unix.
  final String lineEnding;

  /// Numbers are written plainly (no grouping) with this decimal mark.
  final String decimalSeparator;

  final CsvGroupLabels groupLabels;

  /// Prefix the output with U+FEFF, which makes Excel read it as UTF-8.
  final bool byteOrderMark;

  /// Excel-friendly for locales with a comma decimal mark.
  static const europeanExcel = CsvExportOptions(
    delimiter: ';',
    decimalSeparator: ',',
    byteOrderMark: true,
  );
}

/// Writes a [CubeLayout] — the rows and columns exactly as expanded — as
/// CSV text, the same grid `CubeView` shows and `tessera_xlsx` exports:
/// header rows for the column dimensions and the aggregate names, header
/// columns for the row dimensions, one value column per aggregate under
/// each column entry (see [CubeGrid]). Numbers are written plainly;
/// labels come from [strings].
final class CsvCubeExporter {
  const CsvCubeExporter({
    this.strings = const TesseraStringsEn(),
    this.options = const CsvExportOptions(),
    this.emptyGroupLabel,
    this.rowSummaryLabel,
    this.columnSummaryLabel,
  });

  final TesseraStrings strings;
  final CsvExportOptions options;

  /// Overrides of the localized header texts, as on `CubeView`.
  final String? emptyGroupLabel;
  final String? rowSummaryLabel;
  final String? columnSummaryLabel;

  /// The CSV text. [aggregates] selects and orders the value columns under
  /// each column entry; default: every aggregate of the spec.
  String export(CubeLayout layout, {List<Aggregate>? aggregates}) {
    final out = StringBuffer();
    writeTo(out, layout, aggregates: aggregates);
    return out.toString();
  }

  /// Like [export], into [sink] (a file's `IOSink`, a `StringBuffer`).
  void writeTo(
    StringSink sink,
    CubeLayout layout, {
    List<Aggregate>? aggregates,
  }) {
    final grid = CubeGrid.of(
      layout,
      strings: strings,
      aggregates: aggregates,
      emptyGroupLabel: emptyGroupLabel,
      rowSummaryLabel: rowSummaryLabel,
      columnSummaryLabel: columnSummaryLabel,
    );
    if (options.byteOrderMark) sink.write('﻿');
    for (var r = 0; r < grid.rowCount; r++) {
      final row = grid.row(r);
      for (var c = 0; c < row.length; c++) {
        if (c > 0) sink.write(options.delimiter);
        sink.write(_field(_text(row[c])));
      }
      sink.write(options.lineEnding);
    }
  }

  String _text(GridCell cell) {
    if (!cell.isOrigin && options.groupLabels == CsvGroupLabels.origin) {
      return '';
    }
    return switch (cell.value) {
      null => '',
      final num v => formatNumber(v, options.decimalSeparator),
      final bool v => v.toString(),
      final DateTime v => v.toIso8601String(),
      final v => v.toString(),
    };
  }

  /// Integral doubles without a fraction; other doubles rounded to 15
  /// significant digits (what a spreadsheet displays), which drops the
  /// noise of summed decimals such as `135034.64000000004`; with
  /// [decimalSeparator].
  static String formatNumber(num v, String decimalSeparator) {
    if (v is double &&
        v.isFinite &&
        v == v.truncateToDouble() &&
        v.abs() < 9007199254740992) {
      return v.truncate().toString(); // exact below 2^53
    }
    final s = v is double && v.isFinite
        ? double.parse(v.toStringAsPrecision(15)).toString()
        : v.toString();
    return decimalSeparator == '.' ? s : s.replaceAll('.', decimalSeparator);
  }

  String _field(String s) {
    final q = options.quote;
    final needsQuoting =
        s.contains(options.delimiter) ||
        s.contains(q) ||
        s.contains('\n') ||
        s.contains('\r') ||
        (s.isNotEmpty && (s.startsWith(' ') || s.endsWith(' ')));
    return needsQuoting ? '$q${s.replaceAll(q, '$q$q')}$q' : s;
  }
}
