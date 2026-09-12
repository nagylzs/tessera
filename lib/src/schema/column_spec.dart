import 'column_type.dart';

/// Converts a raw source value (usually a [String]) into the Dart value stored
/// for the column, or `null` when the value should be treated as missing.
///
/// Throwing from a parser marks the value as a parse error, which the importer
/// handles according to its [TypeMismatchPolicy].
typedef ValueParser = Object? Function(Object? raw);

/// Describes one column of a [DataSource] and how to import it.
///
/// A [ColumnSpec] is produced by [inferSchema] and can then be adjusted by the
/// user (change the type, exclude the column, supply a custom parser for an
/// unusual date format, …) before the data is imported into a [FactTable].
final class ColumnSpec {
  const ColumnSpec({
    required this.name,
    required this.type,
    this.label,
    this.include = true,
    this.format,
    this.parser,
    this.nullValues = defaultNullValues,
  });

  /// Raw strings that are read as a missing value when no [parser] is given.
  static const defaultNullValues = {
    '',
    'null',
    'NULL',
    'n/a',
    'N/A',
    'NA',
    '-',
  };

  /// Column name as it appears in the source. Unique within a [Schema].
  final String name;

  /// Human readable name; defaults to [name].
  final String? label;

  /// Type the values are converted to.
  final ColumnType type;

  /// When `false` the column is skipped entirely during import.
  final bool include;

  /// Declarative parsing hint interpreted per [type]: a date pattern such as
  /// `dd.MM.yyyy` for [ColumnType.date]/[ColumnType.dateTime], or a locale
  /// such as `hu_HU` (decimal comma, space as thousands separator) for numeric
  /// types. Ignored when [parser] is set.
  final String? format;

  /// Escape hatch for anything [format] cannot express. Receives the raw
  /// source value and must return a value of [type] (or `null`).
  final ValueParser? parser;

  /// Raw strings treated as missing values. Ignored when [parser] is set.
  final Set<String> nullValues;

  String get displayLabel => label ?? name;

  ColumnSpec copyWith({
    String? label,
    ColumnType? type,
    bool? include,
    String? format,
    ValueParser? parser,
    Set<String>? nullValues,
  }) {
    return ColumnSpec(
      name: name,
      label: label ?? this.label,
      type: type ?? this.type,
      include: include ?? this.include,
      format: format ?? this.format,
      parser: parser ?? this.parser,
      nullValues: nullValues ?? this.nullValues,
    );
  }

  @override
  String toString() => 'ColumnSpec($name: $type${include ? '' : ', excluded'})';
}
