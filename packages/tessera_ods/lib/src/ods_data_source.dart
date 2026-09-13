import 'dart:typed_data';

import 'package:tessera/tessera.dart';

import 'ods_document.dart';
import 'ods_sheet_reader.dart';

/// How a sheet is read by [OdsDataSource].
final class OdsOptions {
  const OdsOptions({
    this.sheet,
    this.hasHeader = true,
    this.skipRows = 0,
    this.trim = true,
  });

  /// Name of the sheet to read; `null` reads the first one.
  final String? sheet;

  /// Whether the first row after [skipRows] holds the column names. When
  /// `false`, columns are named `A`, `B`, … after their position.
  final bool hasHeader;

  /// Rows to discard before the header (title lines), counted by sheet row
  /// number, so blank title rows count too.
  final int skipRows;

  /// Strip whitespace around text cells.
  final bool trim;
}

/// A [DataSource] over one sheet of an OpenDocument spreadsheet.
///
/// Cells are delivered typed where the sheet is: numbers as [int] when
/// written without a fraction, else [double]; dates and date-times as UTC
/// [DateTime]; booleans as [bool]; strings as [String] (empty ones as
/// `null`); formulas as their cached value. `inferSchema` reads the types
/// off the values; [declaredSchema] is `null` because a column may still
/// mix types.
///
/// The sheet is parsed as a stream of XML events, so no cell model is
/// built; each call to [rows] parses it again, as the [DataSource] contract
/// requires. Rows are delivered in [columnNames] order and length: missing
/// cells are `null`, cells beyond the last column are dropped. Empty rows
/// are not delivered.
///
/// A source built with [OdsDataSource.fromData] is sendable to another
/// isolate (`loadFactsInIsolate`).
final class OdsDataSource implements DataSource {
  /// Reads a document already in memory (a downloaded file, an asset).
  OdsDataSource.fromData(
    Uint8List bytes, {
    this.name = 'document.ods',
    this.options = const OdsOptions(),
  }) : _data = bytes,
       _openBytes = null;

  /// Reads a document through [open], invoked once per iteration. A closure
  /// that captures non-sendable state makes the source unusable in another
  /// isolate; prefer [OdsDataSource.fromData] there.
  OdsDataSource.fromBytes(
    Future<Uint8List> Function() open, {
    this.name = 'document.ods',
    this.options = const OdsOptions(),
  }) : _data = null,
       _openBytes = open;

  @override
  final String name;

  final OdsOptions options;

  final Uint8List? _data;
  final Future<Uint8List> Function()? _openBytes;

  /// Always `null`: a sheet's columns are typed per cell, so the types are
  /// inferred from the values.
  @override
  Schema? get declaredSchema => null;

  Future<OdsDocument> _document() async =>
      OdsDocument.parse(_data ?? await _openBytes!());

  int get _firstRow => options.skipRows + 1;

  Iterable<SheetRow> _rows(OdsDocument doc) {
    if (options.sheet != null && !doc.sheetNames.contains(options.sheet)) {
      throw ArgumentError.value(
        options.sheet,
        'sheet',
        'no such sheet (sheets: ${doc.sheetNames.join(', ')})',
      );
    }
    return readOdsRows(doc.contentXml, options.sheet, trim: options.trim);
  }

  @override
  Future<List<String>> columnNames() async {
    final first = _rows(await _document())
        .where((r) => r.number >= _firstRow)
        .firstOrNull;
    if (first == null) return const [];
    final width = _width(first);
    if (!options.hasHeader) {
      return [for (var c = 0; c < width; c++) columnLetters(c)];
    }
    return _uniqueNames([
      for (var c = 0; c < width; c++) first.cells[c]?.toString() ?? '',
    ]);
  }

  @override
  Stream<SourceRow> rows() async* {
    int? width;
    for (final row in _rows(await _document())) {
      if (row.number < _firstRow) continue;
      if (width == null) {
        width = _width(row);
        if (options.hasHeader) continue;
      }
      yield [for (var c = 0; c < width; c++) row.cells[c]];
    }
  }

  /// Non-empty rows counted with a cheap scan of the XML (no values are
  /// parsed), minus the skipped rows and the header.
  @override
  Future<int?> estimatedRowCount() async {
    final doc = await _document();
    var n = 0;
    for (final row in _rows(doc)) {
      if (row.number >= _firstRow) n++;
    }
    return options.hasHeader ? (n - 1).clamp(0, n) : n;
  }

  static int _width(SheetRow first) => first.cells.isEmpty
      ? 0
      : first.cells.keys.reduce((a, b) => a > b ? a : b) + 1;

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
