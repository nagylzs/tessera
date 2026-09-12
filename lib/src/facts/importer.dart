import '../schema/column_spec.dart';
import '../schema/column_type.dart';
import '../schema/schema.dart';
import '../schema/value_parsing.dart';
import '../source/data_source.dart';
import '../source/schema_inference.dart';
import 'fact_table.dart';
import 'fact_table_impl.dart';

/// What the importer does when a value does not fit its column's declared
/// [ColumnType].
enum TypeMismatchPolicy {
  /// Widen the column to the narrowest type that fits every value seen so
  /// far (see [ColumnType.canWidenTo]), re-encoding the rows already stored.
  /// The default: the import always succeeds and no row is lost. Note that
  /// already-parsed values are converted from their typed form, so when an
  /// integer column widens to text, an original `007` has become `7`.
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
/// Text cells are parsed with the column's [ColumnSpec.numberSyntax],
/// [ColumnSpec.format] and [ColumnSpec.nullValues] — the same rules
/// [inferSchema] used — or with its custom [ColumnSpec.parser]. Typed cells
/// are accepted when their Dart type matches the column.
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

  /// Throws [ArgumentError] if the schema names a column the source lacks.
  Future<ImportResult> import(DataSource source, Schema schema) async {
    final names = await source.columnNames();
    final specs = schema.included.toList();
    final indices = <int>[];
    for (final spec in specs) {
      final i = names.indexOf(spec.name);
      if (i < 0) {
        throw ArgumentError.value(spec.name, 'schema', 'column not in source');
      }
      indices.add(i);
    }
    final builders = [
      for (final spec in specs) ColumnBuilder.create(spec.name, spec.type),
    ];
    final currentSpecs = List.of(specs);

    final nullified = <String, int>{};
    final widened = <String, ColumnType>{};
    final issues = <ImportIssue>[];
    var issuesTruncated = false;

    void report(ImportIssue issue) {
      if (issues.length < maxIssues) {
        issues.add(issue);
      } else {
        issuesTruncated = true;
      }
    }

    var rowIndex = 0;
    await for (final row in source.rows()) {
      for (var j = 0; j < specs.length; j++) {
        final idx = indices[j];
        final raw = idx < row.length ? row[idx] : null;
        var spec = currentSpecs[j];
        var value = _convert(raw, spec);
        if (value is _Mismatch) {
          switch (policy) {
            case TypeMismatchPolicy.fail:
              throw ImportException(
                ImportIssue(
                  row: rowIndex,
                  column: spec.name,
                  raw: raw,
                  message: value.message,
                ),
              );
            case TypeMismatchPolicy.nullify:
              nullified.update(spec.name, (n) => n + 1, ifAbsent: () => 1);
              report(
                ImportIssue(
                  row: rowIndex,
                  column: spec.name,
                  raw: raw,
                  message: value.message,
                ),
              );
              value = null;
            case TypeMismatchPolicy.widen:
              final target = _widenTarget(spec.type, _narrowestType(raw, spec));
              spec = spec.copyWith(type: target);
              currentSpecs[j] = spec;
              builders[j] = builders[j].widenTo(target);
              widened[spec.name] = target;
              value = _convert(raw, spec);
              if (value is _Mismatch) {
                // Cannot happen: everything fits text. Keep the row anyway.
                value = null;
              }
          }
        }
        builders[j].add(value);
      }
      rowIndex++;
    }

    final columns = [
      for (var j = 0; j < specs.length; j++)
        builders[j].build(currentSpecs[j].displayLabel),
    ];
    return ImportResult(
      facts: FactTableImpl(Schema(currentSpecs), columns, rowIndex),
      report: ImportReport(
        rowsRead: rowIndex,
        rowsImported: rowIndex,
        nullifiedPerColumn: Map.unmodifiable(nullified),
        widenedColumns: Map.unmodifiable(widened),
        issues: List.unmodifiable(issues),
        issuesTruncated: issuesTruncated,
      ),
    );
  }

  /// Converts [raw] to a value of `spec.type`, `null`, or a [_Mismatch].
  static Object? _convert(Object? raw, ColumnSpec spec) {
    if (raw == null) return null;
    final parser = spec.parser;
    if (parser != null) {
      final Object? parsed;
      try {
        parsed = parser(raw);
      } catch (e) {
        return _Mismatch('parser threw: $e');
      }
      if (parsed == null) return null;
      final coerced = _coerce(parsed, spec.type);
      return coerced is _Mismatch
          ? _Mismatch(
              'parser returned ${parsed.runtimeType}, expected ${spec.type.name}',
            )
          : coerced;
    }
    if (raw is String) {
      final s = raw.trim();
      if (spec.nullValues.contains(s)) return null;
      final parsed = _parseText(s, spec.type, spec);
      if (parsed == null) return _Mismatch('not a valid ${spec.type.name}');
      return spec.type == ColumnType.text ? raw : parsed;
    }
    return _coerce(raw, spec.type);
  }

  /// Parses trimmed text as [type]; `null` on failure. Text always succeeds.
  static Object? _parseText(String s, ColumnType type, ColumnSpec spec) {
    switch (type) {
      case ColumnType.text:
        return s;
      case ColumnType.integer:
        return spec.numberSyntax.parseInteger(s);
      case ColumnType.number:
        return spec.numberSyntax.parseNumber(s);
      case ColumnType.boolean:
        return parseBoolean(s);
      case ColumnType.date:
      case ColumnType.dateTime:
        final format = spec.format;
        if (format != null) {
          final v = DatePattern.of(format).parse(s);
          return v != null && (type == ColumnType.dateTime || _isMidnight(v))
              ? v
              : null;
        }
        for (final f in defaultDateFormats) {
          final v = DatePattern.of(f).parse(s);
          if (v != null) {
            return type == ColumnType.dateTime || _isMidnight(v) ? v : null;
          }
        }
        return null;
    }
  }

  /// Accepts an already-typed value for [type], converting where lossless.
  static Object? _coerce(Object value, ColumnType type) {
    final ok = switch (type) {
      ColumnType.text => true,
      ColumnType.integer => value is int,
      ColumnType.number => value is num,
      ColumnType.boolean => value is bool,
      ColumnType.date => value is DateTime && _isMidnight(value),
      ColumnType.dateTime => value is DateTime,
    };
    if (!ok) return _Mismatch('${value.runtimeType} is not a ${type.name}');
    return switch (type) {
      ColumnType.text => ColumnBuilder.stringify(value),
      ColumnType.number => (value as num).toDouble(),
      _ => value,
    };
  }

  /// The narrowest type [raw] fits, using the same order as inference.
  static ColumnType _narrowestType(Object? raw, ColumnSpec spec) {
    if (raw is String) {
      final s = raw.trim();
      if (spec.numberSyntax.parseInteger(s) != null) return ColumnType.integer;
      if (spec.numberSyntax.parseNumber(s) != null) return ColumnType.number;
      if (parseBoolean(s) != null) return ColumnType.boolean;
      final formats = [
        if (spec.format != null) spec.format!,
        ...defaultDateFormats,
      ];
      for (final f in formats) {
        final v = DatePattern.of(f).parse(s);
        if (v != null) {
          return _isMidnight(v) ? ColumnType.date : ColumnType.dateTime;
        }
      }
      return ColumnType.text;
    }
    return switch (raw) {
      int() => ColumnType.integer,
      double() => ColumnType.number,
      bool() => ColumnType.boolean,
      DateTime() => _isMidnight(raw) ? ColumnType.date : ColumnType.dateTime,
      _ => ColumnType.text,
    };
  }

  /// Narrowest type both [current] and [needed] widen to.
  static ColumnType _widenTarget(ColumnType current, ColumnType needed) {
    for (final t in _narrowestFirst) {
      if (current.canWidenTo(t) && needed.canWidenTo(t)) return t;
    }
    return ColumnType.text;
  }

  static const _narrowestFirst = [
    ColumnType.integer,
    ColumnType.number,
    ColumnType.boolean,
    ColumnType.date,
    ColumnType.dateTime,
    ColumnType.text,
  ];

  static bool _isMidnight(DateTime d) =>
      d.hour == 0 && d.minute == 0 && d.second == 0 && d.millisecond == 0;
}

final class _Mismatch {
  const _Mismatch(this.message);
  final String message;
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
