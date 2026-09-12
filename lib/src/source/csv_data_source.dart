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
  }) : _openText = (() => Stream.value(text));

  /// Reads from a re-openable byte stream (a file, a network response, an
  /// asset). [open] is invoked once per iteration.
  CsvDataSource.fromBytes(
    Stream<List<int>> Function() open, {
    this.name = 'csv',
    this.options = const CsvOptions(),
    Encoding encoding = utf8,
  }) : _openText = (() => open().transform(encoding.decoder));

  final Stream<String> Function() _openText;
  List<String>? _columnNames;

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
