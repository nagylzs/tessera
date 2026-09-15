import 'dart:convert';

import 'column_spec.dart';

/// The ordered list of columns of a [DataSource] together with their import
/// settings.
///
/// A schema is immutable; use [replace] / [copyWith] to derive modified
/// versions, e.g. from a UI that lets the user override inferred types.
final class Schema {
  Schema(List<ColumnSpec> columns) : columns = List.unmodifiable(columns) {
    final names = <String>{};
    for (final c in columns) {
      if (!names.add(c.name)) {
        throw ArgumentError.value(c.name, 'columns', 'duplicate column name');
      }
    }
  }

  final List<ColumnSpec> columns;

  /// Columns that will be imported.
  Iterable<ColumnSpec> get included => columns.where((c) => c.include);

  ColumnSpec? operator [](String name) {
    for (final c in columns) {
      if (c.name == name) return c;
    }
    return null;
  }

  /// Returns a schema with the column named `spec.name` replaced by [spec].
  Schema replace(ColumnSpec spec) =>
      Schema([for (final c in columns) c.name == spec.name ? spec : c]);

  Schema copyWith({List<ColumnSpec>? columns}) =>
      Schema(columns ?? this.columns);

  /// A canonical key for the *structure* of the source this schema
  /// describes: the JSON encoding of the column names, in order — for
  /// example `["region","product","amount"]`.
  ///
  /// Two sources with the same columns in the same order share the key
  /// whatever their contents, so an application can remember a user's
  /// schema edits (or a whole pivot layout) per structure and apply them
  /// to the next file of the same shape. The key is built from names on
  /// purpose: inferred types depend on the sampled rows and can differ
  /// between two files of the same structure, which is exactly when a
  /// remembered schema is worth applying. Take the key from the schema
  /// [inferSchema] returned (it lists every source column, whatever the
  /// user later excludes). Excluded columns and labels do not change it.
  String get structureKey => jsonEncode([for (final c in columns) c.name]);

  @override
  String toString() => 'Schema(${columns.join(', ')})';
}
