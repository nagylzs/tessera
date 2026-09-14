import '../schema/column_type.dart';

/// The static type of an expression or of a column as seen by the
/// expression language.
///
/// Every type is nullable: a missing value ("(empty)") propagates through
/// arithmetic and comparisons the way SQL's `NULL` does. [date] covers both
/// [ColumnType.date] and [ColumnType.dateTime]; [number] covers
/// [ColumnType.integer] and [ColumnType.number].
enum ExprType {
  number,
  text,
  boolean,
  date;

  /// The expression type of a column type.
  static ExprType of(ColumnType type) => switch (type) {
    ColumnType.text => text,
    ColumnType.integer || ColumnType.number => number,
    ColumnType.boolean => boolean,
    ColumnType.date || ColumnType.dateTime => date,
  };

  /// Whether `<`, `<=`, `>`, `>=` and `between` apply.
  bool get isOrdered => this != boolean;
}
