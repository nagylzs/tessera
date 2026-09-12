import '../schema/column_type.dart';
import '../schema/schema.dart';
import 'dimension.dart';
import 'measure.dart';

/// Metadata about one column of a [FactTable].
abstract interface class FactColumn {
  String get name;
  String get label;
  ColumnType get type;
  int get nullCount;
  int get distinctCount;
}

/// The in-memory database produced by importing a [DataSource].
///
/// A fact table is immutable once built. Rows are addressed by index
/// (`0 ≤ row < rowCount`) and every accessor is cheap and allocation free, so
/// aggregation can scan all rows in a tight loop.
///
/// Implementations store columns in typed lists with dictionary encoding for
/// text and date columns: each distinct value is kept once and rows hold
/// small integer codes. The table can therefore be moved to an isolate
/// without copying.
abstract interface class FactTable {
  /// The schema the table was imported with (excluded columns removed and
  /// widened types applied).
  Schema get schema;

  int get rowCount;

  List<FactColumn> get columns;

  /// Throws [ArgumentError] for an unknown column.
  FactColumn column(String name);

  /// Like [column] but `null` for an unknown column.
  FactColumn? findColumn(String name);

  /// Raw stored value of [column] in [row]; `null` for missing values.
  Object? valueAt(int row, String column);

  /// Value of [dimension] in [row] (i.e. `dimension.valueOf(valueAt(...))`,
  /// possibly cached).
  Object? dimensionValue(int row, Dimension dimension);

  /// Value of [measure] in [row]; `null` for missing values.
  double? measureValue(int row, Measure measure);

  /// All distinct values of [dimension] in the table, ordered by
  /// [Dimension.compareValues]. Includes `null` when any row lacks a value.
  List<Object?> distinctValues(Dimension dimension);

  /// Number of rows whose [dimension] value equals [value].
  int countWhere(Dimension dimension, Object? value);
}
