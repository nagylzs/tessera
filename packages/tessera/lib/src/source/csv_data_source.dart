import 'dart:convert';

import '../schema/schema.dart';
import 'csv_parser.dart';
import 'data_source.dart';

/// Parsing options for [CsvDataSource].
final class CsvOptions {
  const CsvOptions({
    this.delimiter = ',',
    this.quote = '"',
    this.hasHeader = true,
    this.skipLeadingLines = 0,
    this.trimCells = false,
  }) : assert(delimiter.length == 1, 'delimiter must be one character'),
       assert(quote.length == 1, 'quote must be one character');

  /// Field separator. Use `;` for many European locales, `\t` for TSV.
  final String delimiter;

  final String quote;

  /// When `false`, columns are named `column1`, `column2`, … after the
  /// width of the first record.
  final bool hasHeader;

  /// Lines to discard before the header (comment or title lines).
  final int skipLeadingLines;

  /// Strip whitespace around unquoted cells.
  final bool trimCells;
}

/// A [DataSource] that reads delimited text.
///
/// All cells are produced as [String]s; type conversion happens during import
/// according to the [Schema]. Byte sources are decoded and parsed
/// incrementally, so the file never has to be fully in memory as text.
///
/// Records shorter than the header are padded with `null`; longer ones keep
/// their extra cells (the importer ignores them). Blank lines are skipped.
/// Duplicate or empty header names are made unique (`name_2`, `column3`).
final class CsvDataSource implements DataSource {
  /// Reads from a string already in memory.
  CsvDataSource.fromString(
    String text, {
    this.name = 'csv',
    this.options = const CsvOptions(),
  }) : _openText = (() => Stream.value(text)),
       _length = text.length;

  /// Reads from a re-openable byte stream (a file, a network response, an
  /// asset). [open] is invoked once per iteration. Pass the total [length]
  /// in bytes when you know it (a file's size) to enable
  /// [estimatedRowCount].
  CsvDataSource.fromBytes(
    Stream<List<int>> Function() open, {
    this.name = 'csv',
    this.options = const CsvOptions(),
    Encoding encoding = utf8,
    this._length,
  }) : _openText = (() => open().transform(encoding.decoder));

  /// Reads from bytes already in memory (a downloaded file, an asset).
  /// Unlike [CsvDataSource.fromBytes] this needs no callback, so the source
  /// is always sendable to another isolate.
  CsvDataSource.fromData(
    List<int> bytes, {
    this.name = 'csv',
    this.options = const CsvOptions(),
    Encoding encoding = utf8,
  }) : _openText = (() => Stream.value(encoding.decode(bytes))),
       _length = bytes.length;

  /// Records read to estimate the average row length.
  static const _estimateSample = 200;

  final Stream<String> Function() _openText;
  final int? _length;
  List<String>? _columnNames;
  int? _estimatedRows;

  @override
  final String name;

  final CsvOptions options;

  /// Always `null`: CSV carries no type information.
  @override
  Schema? get declaredSchema => null;

  Stream<List<String>> _records() => parseCsv(_openText(), options);

  @override
  Future<List<String>> columnNames() async {
    final cached = _columnNames;
    if (cached != null) return cached;
    List<String>? first;
    await for (final record in _records()) {
      first = record;
      break;
    }
    final names = first == null
        ? const <String>[]
        : options.hasHeader
        ? _uniqueNames(first)
        : [for (var i = 1; i <= first.length; i++) 'column$i'];
    return _columnNames = List.unmodifiable(names);
  }

  @override
  Stream<SourceRow> rows() async* {
    final width = (await columnNames()).length;
    var skipHeader = options.hasHeader;
    await for (final record in _records()) {
      if (skipHeader) {
        skipHeader = false;
        continue;
      }
      if (record.length >= width) {
        yield record;
      } else {
        yield [...record, for (var i = record.length; i < width; i++) null];
      }
    }
  }

  /// Total length divided by the average length of the first
  /// [_estimateSample] records; `null` when the length is unknown. Exact
  /// when the source is shorter than the sample.
  @override
  Future<int?> estimatedRowCount() async {
    final cached = _estimatedRows;
    if (cached != null) return cached;
    final length = _length;
    if (length == null) return null;
    final stats = CsvParseStats();
    var complete = true;
    await for (final _ in parseCsv(_openText(), options, stats: stats)) {
      if (stats.records >= _estimateSample) {
        complete = false;
        break;
      }
    }
    final headerRecords = options.hasHeader ? 1 : 0;
    final int rows;
    if (complete || stats.records == 0) {
      rows = stats.records - headerRecords;
    } else {
      final average = stats.characters / stats.records;
      rows = (length / average).round() - headerRecords;
    }
    return _estimatedRows = rows < 0 ? 0 : rows;
  }

  static List<String> _uniqueNames(List<String> header) {
    final seen = <String>{};
    final names = <String>[];
    for (var i = 0; i < header.length; i++) {
      var name = header[i].trim();
      if (name.isEmpty) name = 'column${i + 1}';
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
