import '../schema/column_spec.dart';
import '../schema/column_type.dart';
import '../schema/schema.dart';
import '../schema/value_parsing.dart';
import 'data_source.dart';

/// Controls how [inferSchema] samples and interprets a [DataSource].
final class InferenceOptions {
  const InferenceOptions({
    this.sampleRows = 1000,
    this.nullValues = ColumnSpec.defaultNullValues,
    this.dateFormats = const [
      'yyyy-MM-dd',
      'yyyy-MM-ddTHH:mm:ss',
      'yyyy-MM-dd HH:mm:ss',
      'yyyy-MM-dd HH:mm',
    ],
    this.numberSyntax = NumberSyntax.standard,
  });

  /// Maximum number of rows read from the source. The iteration is abandoned
  /// after this many rows, so huge sources are cheap to inspect.
  final int sampleRows;

  /// Raw strings treated as missing during inference and, through the
  /// resulting [ColumnSpec.nullValues], during import.
  final Set<String> nullValues;

  /// Date patterns tried, in order, before falling back to [ColumnType.text].
  /// The first pattern that matches every sampled value of a column is
  /// recorded in [ColumnSpec.format]. See [DatePattern] for the syntax.
  final List<String> dateFormats;

  /// How numeric text is written. Recorded in [ColumnSpec.numberSyntax] for
  /// numeric columns.
  final NumberSyntax numberSyntax;
}

/// Guesses a [Schema] for [source] from a prefix of its rows.
///
/// For each column the narrowest [ColumnType] that fits every sampled
/// non-null value is chosen, in the order integer, number, boolean, date,
/// dateTime, text. A column whose sampled values are all null becomes
/// [ColumnType.text]. Text cells are parsed with [InferenceOptions]; typed
/// cells (from an already-typed source) are classified by their Dart type.
///
/// Because only a sample is read, the result is a *proposal*: later rows may
/// contradict it, which the importer resolves via its [TypeMismatchPolicy].
///
/// If the source has a [DataSource.declaredSchema] it is returned as-is.
Future<Schema> inferSchema(
  DataSource source, {
  InferenceOptions options = const InferenceOptions(),
}) async {
  final declared = source.declaredSchema;
  if (declared != null) return declared;

  final names = await source.columnNames();
  final stats = [for (final _ in names) _ColumnStats(options)];

  if (options.sampleRows > 0 && names.isNotEmpty) {
    var read = 0;
    await for (final row in source.rows()) {
      for (var i = 0; i < names.length; i++) {
        stats[i].observe(i < row.length ? row[i] : null);
      }
      if (++read >= options.sampleRows) break;
    }
  }

  return Schema([
    for (var i = 0; i < names.length; i++) stats[i].toSpec(names[i]),
  ]);
}

/// Candidate types still possible for one column after the values seen.
class _ColumnStats {
  _ColumnStats(this.options) : formats = List.of(options.dateFormats);

  final InferenceOptions options;

  int nonNull = 0;
  bool integer = true;
  bool number = true;
  bool boolean = true;

  /// Date patterns that matched every text value so far.
  List<String> formats;
  bool sawText = false;
  bool typedDate = true; // no typed value rules out date/dateTime
  bool sawTypedDate = false;
  bool typedHasTime = false;

  bool get anyDate =>
      typedDate && (sawText ? formats.isNotEmpty : sawTypedDate);

  void observe(Object? value) {
    if (value == null) return;
    if (value is String) {
      final s = value.trim();
      if (options.nullValues.contains(s)) return;
      nonNull++;
      sawText = true;
      final syntax = options.numberSyntax;
      if (integer) integer = syntax.parseInteger(s) != null;
      if (number) number = syntax.parseNumber(s) != null;
      if (boolean) boolean = parseBoolean(s) != null;
      if (formats.isNotEmpty) {
        formats = [
          for (final f in formats)
            if (DatePattern.of(f).parse(s) != null) f,
        ];
      }
      return;
    }
    nonNull++;
    switch (value) {
      case int():
        boolean = false;
        typedDate = false;
      case double():
        integer = false;
        boolean = false;
        typedDate = false;
      case bool():
        integer = false;
        number = false;
        typedDate = false;
      case DateTime():
        integer = false;
        number = false;
        boolean = false;
        sawTypedDate = true;
        if (value.hour != 0 ||
            value.minute != 0 ||
            value.second != 0 ||
            value.millisecond != 0) {
          typedHasTime = true;
        }
      default:
        integer = false;
        number = false;
        boolean = false;
        typedDate = false;
    }
  }

  ColumnSpec toSpec(String name) {
    if (nonNull == 0) {
      return ColumnSpec(
        name: name,
        type: ColumnType.text,
        nullValues: options.nullValues,
      );
    }
    final ColumnType type;
    String? format;
    if (integer) {
      type = ColumnType.integer;
    } else if (number) {
      type = ColumnType.number;
    } else if (boolean) {
      type = ColumnType.boolean;
    } else if (anyDate) {
      format = sawText ? formats.first : null;
      final hasTime =
          typedHasTime || (format != null && DatePattern.of(format).hasTime);
      type = hasTime ? ColumnType.dateTime : ColumnType.date;
    } else {
      type = ColumnType.text;
    }
    return ColumnSpec(
      name: name,
      type: type,
      format: format,
      numberSyntax: options.numberSyntax,
      nullValues: options.nullValues,
    );
  }
}
