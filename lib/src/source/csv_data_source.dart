import 'dart:convert';

import '../schema/schema.dart';
import 'data_source.dart';

/// Parsing options for [CsvDataSource].
final class CsvOptions {
  const CsvOptions({
    this.delimiter = ',',
    this.quote = '"',
    this.hasHeader = true,
    this.skipLeadingLines = 0,
    this.trimCells = false,
  });

  /// Field separator. Use `;` for many European locales, `\t` for TSV.
  final String delimiter;

  final String quote;

  /// When `false`, columns are named `column1`, `column2`, …
  final bool hasHeader;

  /// Lines to discard before the header (comment or title lines).
  final int skipLeadingLines;

  /// Strip whitespace around every cell.
  final bool trimCells;
}

/// A [DataSource] that reads delimited text.
///
/// All cells are produced as [String]s; type conversion happens during import
/// according to the [Schema]. Byte sources are decoded and parsed
/// incrementally, so the file never has to be fully in memory as text.
final class CsvDataSource implements DataSource {
  /// Reads from a string already in memory.
  CsvDataSource.fromString(
    String text, {
    this.name = 'csv',
    this.options = const CsvOptions(),
  }) : _open = (() => Stream.value(utf8.encode(text))),
       _encoding = utf8;

  /// Reads from a re-openable byte stream (a file, a network response, an
  /// asset). [open] is invoked once per [rows] call.
  CsvDataSource.fromBytes(
    Stream<List<int>> Function() open, {
    this.name = 'csv',
    this.options = const CsvOptions(),
    this._encoding = utf8,
  }) : _open = open;

  // ignore: unused_field
  final Stream<List<int>> Function() _open;
  // ignore: unused_field
  final Encoding _encoding;

  @override
  final String name;

  final CsvOptions options;

  /// Always `null`: CSV carries no type information.
  @override
  Schema? get declaredSchema => null;

  @override
  Future<List<String>> columnNames() => throw UnimplementedError();

  @override
  Stream<SourceRow> rows() => throw UnimplementedError();
}
