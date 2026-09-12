import '../schema/column_type.dart';
import '../schema/schema.dart';
import '../source/data_source.dart';
import '../source/schema_inference.dart';
import 'fact_table.dart';

/// What the importer does when a value does not fit its column's declared
/// [ColumnType].
enum TypeMismatchPolicy {
  /// Widen the column to the narrowest type that fits every value seen so
  /// far (see [ColumnType.canWidenTo]), re-encoding the rows already stored.
  /// The default: the import always succeeds and no data is lost.
  widen,

  /// Keep the declared type and store the offending value as `null`. Every
  /// occurrence is counted in the [ImportReport].
  nullify,

  /// Abort the import with an [ImportException] at the first offending value.
  fail,
}

/// One value that could not be imported as declared.
final class ImportIssue {
  const ImportIssue({
    required this.row,
    required this.column,
    required this.raw,
    required this.message,
  });

  /// Zero-based source row index (header excluded).
  final int row;
  final String column;
  final Object? raw;
  final String message;

  @override
  String toString() => 'row $row, $column: $message ($raw)';
}

/// Thrown by [TypeMismatchPolicy.fail].
final class ImportException implements Exception {
  const ImportException(this.issue);
  final ImportIssue issue;

  @override
  String toString() => 'ImportException: $issue';
}

/// Statistics collected while importing.
final class ImportReport {
  const ImportReport({
    required this.rowsRead,
    required this.rowsImported,
    required this.nullifiedPerColumn,
    required this.widenedColumns,
    required this.issues,
    required this.issuesTruncated,
  });

  final int rowsRead;
  final int rowsImported;

  /// Column name → number of values replaced by `null`.
  final Map<String, int> nullifiedPerColumn;

  /// Column name → type it was widened to, for columns whose type changed.
  final Map<String, ColumnType> widenedColumns;

  /// The first [FactTableImporter.maxIssues] issues, for display.
  final List<ImportIssue> issues;

  /// Whether more issues occurred than were recorded in [issues].
  final bool issuesTruncated;

  bool get hasIssues => issues.isNotEmpty || widenedColumns.isNotEmpty;
}

final class ImportResult {
  const ImportResult({required this.facts, required this.report});
  final FactTable facts;
  final ImportReport report;
}

/// Builds a [FactTable] from a [DataSource] according to a [Schema].
///
/// Expected to be run in an isolate for large sources; both the input
/// (source + schema) and the output ([FactTable] backed by typed lists) are
/// transferable.
final class FactTableImporter {
  const FactTableImporter({
    this.policy = TypeMismatchPolicy.widen,
    this.maxIssues = 100,
  });

  final TypeMismatchPolicy policy;

  /// Cap on [ImportReport.issues] to keep the report small.
  final int maxIssues;

  Future<ImportResult> import(DataSource source, Schema schema) {
    throw UnimplementedError();
  }
}

/// Convenience: infer the schema (unless [schema] is given) and import.
Future<ImportResult> loadFacts(
  DataSource source, {
  Schema? schema,
  InferenceOptions inference = const InferenceOptions(),
  FactTableImporter importer = const FactTableImporter(),
}) async {
  schema ??= await inferSchema(source, options: inference);
  return importer.import(source, schema);
}
