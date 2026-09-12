import '../schema/column_type.dart';
import '../schema/schema.dart';
import 'data_source.dart';

/// Controls how [inferSchema] samples and interprets a [DataSource].
final class InferenceOptions {
  const InferenceOptions({
    this.sampleRows = 1000,
    this.nullValues = const {'', 'null', 'NULL', 'n/a', 'N/A', 'NA', '-'},
    this.dateFormats = const ['yyyy-MM-dd', 'yyyy-MM-ddTHH:mm:ss'],
    this.decimalSeparator = '.',
    this.thousandsSeparators = const {','},
  });

  /// Maximum number of rows read from the source. The iteration is abandoned
  /// after this many rows, so huge sources are cheap to inspect.
  final int sampleRows;

  /// Raw strings treated as missing during inference.
  final Set<String> nullValues;

  /// Date patterns tried, in order, before falling back to [ColumnType.text].
  final List<String> dateFormats;

  final String decimalSeparator;

  /// Characters removed from numeric cells before parsing.
  final Set<String> thousandsSeparators;
}

/// Guesses a [Schema] for [source] from a prefix of its rows.
///
/// For each column the narrowest [ColumnType] that fits every sampled non-null
/// value is chosen; a column whose sampled values are all null becomes
/// [ColumnType.text]. Because only a sample is read, the result is a
/// *proposal*: later rows may contradict it, which the importer resolves via
/// its [TypeMismatchPolicy].
///
/// If the source has a [DataSource.declaredSchema] it is returned as-is.
Future<Schema> inferSchema(
  DataSource source, {
  InferenceOptions options = const InferenceOptions(),
}) {
  throw UnimplementedError();
}
