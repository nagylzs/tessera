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

  @override
  String toString() => 'Schema(${columns.join(', ')})';
}
