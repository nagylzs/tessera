import '../cube/filter.dart';
import '../facts/fact_table.dart';
import '../schema/column_type.dart';
import 'cube_export_theme.dart';

/// One column of an [ExportTable]: its [header] and how its values are
/// shown — format-neutral, so the same description serves every table
/// exporter (`CsvTableExporter`, `XlsxTableExporter`, `OdsTableExporter`).
///
/// [numberFormat] and [width] are display hints for the formats that format
/// cells (spreadsheets); text formats such as CSV write values plainly.
final class ExportColumn {
  const ExportColumn(
    this.header, {
    this.name,
    this.type,
    this.numberFormat,
    this.width,
  });

  /// The text of the header row.
  final String header;

  /// The source column's name, for an [ExportTable.ofFacts] column; what
  /// [ExportTable.withColumn] and exporter options keyed by column find it
  /// by ([key]).
  final String? name;

  /// The values' type, when known. It decides whether a [DateTime] is a
  /// calendar day or a point in time ([showsTime]); `null` takes each
  /// value as it comes.
  final ColumnType? type;

  /// Decimals and grouping of the numbers; `null` shows them as they are.
  final NumberFormat? numberFormat;

  /// A fixed width in characters; `null` sizes the column to its content.
  final double? width;

  /// [name], or the [header] for a column without one.
  String get key => name ?? header;

  /// Whether [value] is shown with its time of day: always in a
  /// [ColumnType.dateTime] column, never in a [ColumnType.date] one, and
  /// otherwise when it has a time of day other than midnight.
  bool showsTime(DateTime value) => switch (type) {
    ColumnType.dateTime => true,
    ColumnType.date => false,
    _ =>
      value.hour != 0 ||
          value.minute != 0 ||
          value.second != 0 ||
          value.millisecond != 0 ||
          value.microsecond != 0,
  };

  ExportColumn copyWith({
    String? header,
    String? name,
    ColumnType? type,
    NumberFormat? numberFormat,
    double? width,
  }) => ExportColumn(
    header ?? this.header,
    name: name ?? this.name,
    type: type ?? this.type,
    numberFormat: numberFormat ?? this.numberFormat,
    width: width ?? this.width,
  );
}

/// A plain table — not a cube — for the table exporters: [columns] and the
/// [rows] under them, each row a list of cell values in column order.
///
/// Values are `num`, `bool`, `DateTime`, `null` (an empty cell) or anything
/// else, which is written as text (`toString()`). A row shorter than the
/// columns leaves the rest empty; extra values are ignored.
///
/// [ExportTable.ofFacts] reads a [FactTable] lazily, so a large table is
/// never copied before it is written.
final class ExportTable {
  const ExportTable(this.columns, this.rows);

  /// The facts of [facts] as a table: the [columns] named (default: every
  /// column, in the table's order) with their labels as headers (names
  /// with `useLabels: false`) and their types; every row — or those of
  /// [rows] when given, e.g. `CubeCell.factRows` — that passes [filter],
  /// e.g. the cube's `CubeSpec.filter`.
  factory ExportTable.ofFacts(
    FactTable facts, {
    List<String>? columns,
    Iterable<int>? rows,
    FactFilter? filter,
    bool useLabels = true,
  }) {
    final names = columns ?? [for (final c in facts.columns) c.name];
    return ExportTable([
      for (final n in names)
        ExportColumn(
          useLabels ? facts.column(n).label : n,
          name: n,
          type: facts.column(n).type,
        ),
    ], _factRows(facts, names, rows, filter));
  }

  final List<ExportColumn> columns;
  final Iterable<List<Object?>> rows;

  /// This table with the column whose [ExportColumn.key] is [key] replaced
  /// by [update] of it; unchanged when there is no such column.
  ///
  /// ```dart
  /// ExportTable.ofFacts(facts).withColumn(
  ///   'total',
  ///   (c) => c.copyWith(numberFormat: const NumberFormat(decimals: 2)),
  /// )
  /// ```
  ExportTable withColumn(
    String key,
    ExportColumn Function(ExportColumn column) update,
  ) => ExportTable([
    for (final c in columns) c.key == key ? update(c) : c,
  ], rows);

  static Iterable<List<Object?>> _factRows(
    FactTable facts,
    List<String> names,
    Iterable<int>? rows,
    FactFilter? filter,
  ) sync* {
    final pass = filter?.compile(facts);
    for (final row in rows ?? Iterable<int>.generate(facts.rowCount)) {
      if (pass != null && !pass(row)) continue;
      yield [for (final n in names) facts.valueAt(row, n)];
    }
  }
}

/// The look of an exported [ExportTable] in the formats that style cells:
/// the header row's fill and font, the data cells' font and the borders.
/// Format-neutral like [CubeExportTheme]: colours are ARGB ints.
final class TableExportTheme {
  const TableExportTheme({
    this.headerFill = 0xFFD9E1F2,
    this.headerFont = const ExportFont(bold: true),
    this.font = const ExportFont(),
    this.borders = false,
    this.borderColor = 0xFFBFBFBF,
  });

  /// The header row's fill (`null` for none) and font.
  final int? headerFill;
  final ExportFont headerFont;

  /// The data cells' font; they have no fill.
  final ExportFont font;

  /// Thin borders around every cell, in [borderColor].
  final bool borders;
  final int borderColor;

  TableExportTheme copyWith({
    int? headerFill,
    ExportFont? headerFont,
    ExportFont? font,
    bool? borders,
    int? borderColor,
  }) => TableExportTheme(
    headerFill: headerFill ?? this.headerFill,
    headerFont: headerFont ?? this.headerFont,
    font: font ?? this.font,
    borders: borders ?? this.borders,
    borderColor: borderColor ?? this.borderColor,
  );
}
