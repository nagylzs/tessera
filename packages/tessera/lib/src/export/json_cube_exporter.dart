import 'dart:convert';

import '../cube/aggregate.dart';
import '../cube/cube_layout.dart';
import '../l10n/l10n_en.dart';
import '../l10n/tessera_strings.dart';
import 'csv_cube_exporter.dart';
import 'cube_grid.dart';

/// Shape options of a JSON / JSON Lines export.
final class JsonExportOptions {
  const JsonExportOptions({
    this.groupLabels = CsvGroupLabels.repeat,
    this.pathSeparator = ' / ',
    this.indent,
  });

  /// Whether a row group's label appears in every record of the group
  /// ([CsvGroupLabels.repeat], the default here — records are meant to be
  /// read on their own) or only in the group's first record, `null`
  /// elsewhere ([CsvGroupLabels.origin], what the sheet looks like).
  final CsvGroupLabels groupLabels;

  /// Joins the column group labels and the aggregate name into a field
  /// name: `2024 / Q1 / sum of total`.
  final String pathSeparator;

  /// Pretty-print the JSON array with this indentation (`'  '`); `null`
  /// writes it compact. JSON Lines are always one record per line.
  final String? indent;
}

/// Writes a [CubeLayout] — the rows and columns exactly as expanded — as
/// records: one object per grid row, the row dimensions as fields named
/// after their titles, and one field per column entry and aggregate named
/// from the column labels and the aggregate name. The same grid `CubeView`
/// shows and [CsvCubeExporter] writes, with JSON types: numbers as
/// numbers, dates as ISO 8601 text, blanks as `null`.
///
/// [export] writes a JSON array, [exportLines] / [writeLines] JSON Lines
/// (one record per line), [records] the objects themselves for further
/// processing or `jsonEncode`. Labels come from [strings].
final class JsonCubeExporter {
  const JsonCubeExporter({
    this.strings = const TesseraStringsEn(),
    this.options = const JsonExportOptions(),
    this.emptyGroupLabel,
    this.rowSummaryLabel,
    this.columnSummaryLabel,
  });

  final TesseraStrings strings;
  final JsonExportOptions options;

  /// Overrides of the localized header texts, as on `CubeView`.
  final String? emptyGroupLabel;
  final String? rowSummaryLabel;
  final String? columnSummaryLabel;

  /// The records: field name → value, in grid order. [aggregates] selects
  /// and orders the value fields under each column entry; default: every
  /// aggregate of the spec. Field names are made unique with ` (2)`, ` (3)`
  /// when labels collide.
  List<Map<String, Object?>> records(
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
    final names = fieldNames(grid);
    final repeat = options.groupLabels == CsvGroupLabels.repeat;
    return [
      for (var r = grid.headerRows; r < grid.rowCount; r++)
        {
          for (var c = 0; c < grid.columnCount; c++)
            names[c]: _value(grid.cellAt(r, c), c, repeat),
        },
    ];
  }

  /// One name per grid column: the row dimension titles, then for every
  /// data column its column labels joined by [JsonExportOptions.pathSeparator]
  /// with the aggregate name last.
  List<String> fieldNames(CubeGrid grid) {
    final names = <String>[];
    final seen = <String, int>{};
    String unique(String base) {
      final n = (seen[base] ?? 0) + 1;
      seen[base] = n;
      return n == 1 ? base : '$base ($n)';
    }

    final titleRow = grid.headerRows - 1;
    for (var c = 0; c < grid.headerColumns; c++) {
      final title = _label(grid.cellAt(titleRow, c));
      names.add(unique(title.isEmpty ? 'row' : title));
    }
    for (var c = grid.headerColumns; c < grid.columnCount; c++) {
      final parts = <String>[];
      for (var r = 0; r < grid.headerRows; r++) {
        final cell = grid.cellAt(r, c);
        // A label merged downwards (a summary, a collapsed group) counts
        // once, in its origin row; one merged sideways applies to every
        // column under it.
        if (cell.isLeg || (!cell.isOrigin && cell.originRow != r)) continue;
        final text = _label(cell);
        if (text.isNotEmpty) parts.add(text);
      }
      names.add(unique(parts.join(options.pathSeparator)));
    }
    return names;
  }

  /// The JSON array text.
  String export(CubeLayout layout, {List<Aggregate>? aggregates}) {
    final list = records(layout, aggregates: aggregates);
    final indent = options.indent;
    return indent == null
        ? jsonEncode(list)
        : JsonEncoder.withIndent(indent).convert(list);
  }

  /// The JSON Lines text: one record per line, `\n` after each.
  String exportLines(CubeLayout layout, {List<Aggregate>? aggregates}) {
    final out = StringBuffer();
    writeLines(out, layout, aggregates: aggregates);
    return out.toString();
  }

  /// Like [exportLines], into [sink].
  void writeLines(
    StringSink sink,
    CubeLayout layout, {
    List<Aggregate>? aggregates,
  }) {
    for (final r in records(layout, aggregates: aggregates)) {
      sink.write(jsonEncode(r));
      sink.write('\n');
    }
  }

  static String _label(GridCell cell) => switch (cell.value) {
    null => '',
    final DateTime v => v.toIso8601String(),
    final v => v.toString(),
  };

  static Object? _value(GridCell cell, int column, bool repeat) {
    // A row label merged sideways (a collapsed group spanning the deeper
    // header columns) is not a value of those deeper levels; one merged
    // downwards repeats into its group's records when asked.
    if (!cell.isOrigin && (!repeat || cell.originColumn != column)) {
      return null;
    }
    return switch (cell.value) {
      null => null,
      final num v =>
        v is double && v == v.truncateToDouble() && v.abs() < 9007199254740992
            ? v.truncate()
            : v,
      final bool v => v,
      final DateTime v => v.toIso8601String(),
      final v => v.toString(),
    };
  }
}
