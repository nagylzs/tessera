import 'dart:typed_data';

import 'package:tessera/tessera.dart';

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

  /// Whether the first (non-skipped) row holds the column names. When
  /// `false`, columns are named `A`, `B`, … after their letters.
  final bool hasHeader;

  /// Rows to discard before the header (title lines).
  final int skipRows;

  /// Strip whitespace around text cells.
  final bool trim;
}

/// A [DataSource] over one worksheet of an `.xlsx` workbook.
///
/// Cells are delivered typed where the sheet is: numbers as [double],
/// dates (numbers with a date style) as UTC [DateTime], booleans as [bool],
/// shared and inline strings as [String]. `inferSchema` then reads the
/// types off the values; [declaredSchema] is `null` because a column may
/// still mix types.
///
/// The sheet is parsed as a stream (zip entry → XML events → rows), so a
/// large workbook is not materialised; every call to [rows] parses it
/// again, as the [DataSource] contract requires. A source built with
/// [XlsxDataSource.fromData] is sendable to another isolate.
final class XlsxDataSource implements DataSource {
  /// Reads a workbook already in memory (a downloaded file, an asset).
  XlsxDataSource.fromData(
    Uint8List bytes, {
    this.name = 'workbook.xlsx',
    this.options = const XlsxOptions(),
  }) : _open = (() => Future.value(bytes));

  /// Reads a workbook through [open], invoked once per iteration (a file
  /// read, a network fetch). A closure that captures non-sendable state
  /// makes the source unusable in another isolate; prefer
  /// [XlsxDataSource.fromData] there.
  XlsxDataSource.fromBytes(
    Future<Uint8List> Function() open, {
    this.name = 'workbook.xlsx',
    this.options = const XlsxOptions(),
  }) : _open = open;

  @override
  final String name;

  final XlsxOptions options;

  // Used once the reader exists.
  // ignore: unused_field
  final Future<Uint8List> Function() _open;

  /// Always `null`: a worksheet's columns are typed per cell, so the types
  /// are inferred from the values.
  @override
  Schema? get declaredSchema => null;

  @override
  Future<List<String>> columnNames() =>
      throw UnimplementedError('XlsxDataSource is not implemented yet');

  @override
  Stream<SourceRow> rows() =>
      throw UnimplementedError('XlsxDataSource is not implemented yet');

  /// From the sheet's `dimension` element (`A1:K1001`), minus the header and
  /// skipped rows; `null` when the sheet does not declare one.
  @override
  Future<int?> estimatedRowCount() =>
      throw UnimplementedError('XlsxDataSource is not implemented yet');
}
