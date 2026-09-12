import '../schema/schema.dart';
import 'data_source.dart';

/// A [DataSource] backed by an in-memory list of rows.
///
/// Useful for tests and for feeding already-typed Dart data into Tessera.
final class ListDataSource implements DataSource {
  ListDataSource({
    required List<String> columns,
    required List<SourceRow> rows,
    this.name = 'list',
    this.declaredSchema,
  }) : _columns = List.unmodifiable(columns),
       _rows = List.unmodifiable(rows);

  final List<String> _columns;
  final List<SourceRow> _rows;

  @override
  final String name;

  @override
  final Schema? declaredSchema;

  @override
  Future<List<String>> columnNames() async => _columns;

  @override
  Stream<SourceRow> rows() => Stream.fromIterable(_rows);

  /// Exact.
  @override
  Future<int?> estimatedRowCount() async => _rows.length;
}
