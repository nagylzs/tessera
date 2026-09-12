import '../schema/schema.dart';

/// One row of source data, cell values in [DataSource.columnNames] order.
///
/// Cells are typically [String]s (CSV, text files) but may already be typed
/// values (a source built from Dart objects, JSON, a database cursor…).
typedef SourceRow = List<Object?>;

/// Anything that can be iterated to produce rows of tabular data.
///
/// This is the common interface every importer works against. Implement it to
/// feed Tessera from a custom format. The contract is deliberately minimal:
///
/// * [columnNames] must be available before any row is read.
/// * [rows] may be called more than once; each call starts a fresh iteration.
///   Schema inference only consumes a prefix of the first iteration, the
///   import consumes a second one in full.
/// * No `dart:io` is assumed, so sources work on the web too.
abstract interface class DataSource {
  /// Descriptive name, e.g. the file name. Used in reports and UI only.
  String get name;

  /// Types known up front, when the source is already typed (e.g. built from
  /// Dart objects). `null` means the types must be inferred with
  /// [inferSchema].
  Schema? get declaredSchema;

  /// Column names in cell order.
  Future<List<String>> columnNames();

  /// Opens a fresh iteration over all rows.
  Stream<SourceRow> rows();
}
