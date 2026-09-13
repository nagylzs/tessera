import 'dart:typed_data';

import 'package:tessera/tessera.dart';

import 'xlsx_sheet_reader.dart';
import 'xlsx_workbook.dart';

/// How a worksheet is read by [XlsxDataSource].
final class XlsxOptions {
  const XlsxOptions({
    this.sheet,
    this.hasHeader = true,
    this.skipRows = 0,
    this.trim = true,
  });

  /// Name of the worksheet to read; `null` reads the first one.
  final String? sheet;

  /// Whether the first row after [skipRows] holds the column names. When
  /// `false`, columns are named `A`, `B`, … after their letters.
  final bool hasHeader;

  /// Rows to discard before the header (title lines), counted by sheet row
  /// number, so blank title rows count too.
  final int skipRows;

  /// Strip whitespace around text cells.
  final bool trim;
}

/// A [DataSource] over one worksheet of an `.xlsx` workbook.
///
/// Cells are delivered typed where the sheet is: numbers as [int] when
/// written without a fraction, else [double]; date- or time-formatted
/// numbers as UTC [DateTime]; booleans as [bool]; shared and inline strings
/// as [String] (empty ones as `null`); formulas as their cached value.
/// `inferSchema` reads the types off the values; [declaredSchema] is `null`
/// because a column may still mix types.
///
/// The sheet is parsed as a stream of XML events, so no cell model is
/// built; each call to [rows] parses it again, as the [DataSource] contract
/// requires. Rows are delivered in [columnNames] order and length: missing
/// cells are `null`, cells beyond the last column are dropped. Blank rows
/// the sheet does not store are not delivered.
///
/// A source built with [XlsxDataSource.fromData] is sendable to another
/// isolate (`loadFactsInIsolate`).
final class XlsxDataSource implements DataSource {
  /// Reads a workbook already in memory (a downloaded file, an asset).
  XlsxDataSource.fromData(
    Uint8List bytes, {
    this.name = 'workbook.xlsx',
    this.options = const XlsxOptions(),
  }) : _data = bytes,
       _openBytes = null;

  /// Reads a workbook through [open], invoked once per iteration (a file
  /// read, a network fetch). A closure that captures non-sendable state
  /// makes the source unusable in another isolate; prefer
  /// [XlsxDataSource.fromData] there.
  XlsxDataSource.fromBytes(
    Future<Uint8List> Function() open, {
    this.name = 'workbook.xlsx',
    this.options = const XlsxOptions(),
  }) : _data = null,
       _openBytes = open;

  @override
  final String name;

  final XlsxOptions options;

  final Uint8List? _data;
  final Future<Uint8List> Function()? _openBytes;

  /// Always `null`: a worksheet's columns are typed per cell, so the types
  /// are inferred from the values.
  @override
  Schema? get declaredSchema => null;

  Future<XlsxWorkbook> _workbook() async =>
      XlsxWorkbook.parse(_data ?? await _openBytes!());

  /// Sheet row number of the header (or of the first data row when there is
  /// no header).
  int get _firstRow => options.skipRows + 1;

  @override
  Future<List<String>> columnNames() async {
    final workbook = await _workbook();
    final xml = workbook.sheetXml(options.sheet);
    final rows = readSheetRows(workbook, xml, trim: options.trim);
    final first = rows.where((r) => r.number >= _firstRow).firstOrNull;
    if (first == null) return const [];
    final width = _width(first, sheetDimension(xml));
    if (!options.hasHeader) {
      return [for (var c = 0; c < width; c++) columnLetters(c)];
    }
    return _uniqueNames([
      for (var c = 0; c < width; c++) first.cells[c]?.toString() ?? '',
    ]);
  }

  @override
  Stream<SourceRow> rows() async* {
    final workbook = await _workbook();
    final xml = workbook.sheetXml(options.sheet);
    int? width;
    for (final row in readSheetRows(workbook, xml, trim: options.trim)) {
      if (row.number < _firstRow) continue;
      if (width == null) {
        width = _width(row, sheetDimension(xml));
        if (options.hasHeader) continue;
      }
      yield [for (var c = 0; c < width; c++) row.cells[c]];
    }
  }

  /// From the sheet's `dimension` element (`A1:K1001`), minus the skipped
  /// rows and the header; `null` when the sheet declares no dimension.
  @override
  Future<int?> estimatedRowCount() async {
    final workbook = await _workbook();
    final dimension = sheetDimension(workbook.sheetXml(options.sheet));
    if (dimension == null) return null;
    final n =
        dimension.lastRow - options.skipRows - (options.hasHeader ? 1 : 0);
    return n < 0 ? 0 : n;
  }

  /// Column count: the widest of the header row and the declared dimension.
  static int _width(SheetRow first, ({int lastRow, int lastColumn})? dim) {
    var width = first.cells.isEmpty
        ? 0
        : first.cells.keys.reduce((a, b) => a > b ? a : b) + 1;
    if (dim != null && dim.lastColumn + 1 > width) width = dim.lastColumn + 1;
    return width;
  }

  /// Blank names become the column letters, duplicates get `_2`, `_3`, …
  static List<String> _uniqueNames(List<String> header) {
    final seen = <String>{};
    final names = <String>[];
    for (var i = 0; i < header.length; i++) {
      var name = header[i].trim();
      if (name.isEmpty) name = columnLetters(i);
      var candidate = name;
      var n = 2;
      while (!seen.add(candidate)) {
        candidate = '${name}_${n++}';
      }
      names.add(candidate);
    }
    return names;
  }
}
