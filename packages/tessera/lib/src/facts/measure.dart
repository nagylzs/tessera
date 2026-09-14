import '../expr/expression.dart';
import '../expr/functions.dart';
import 'fact_table.dart';

/// A numeric attribute of the facts that aggregates are computed from.
///
/// A measure is a *view* on the fact table: [ColumnMeasure] (the default
/// constructor) reads a numeric column, [ExpressionMeasure] computes a
/// number from several with an expression (`quantity * unit_price`).
/// Which columns are measures is a matter of use, not of the schema: the
/// same `quantity` column can be summed as a measure and grouped by as a
/// [Dimension]. Measures are value objects identified by [id].
sealed class Measure {
  const Measure._();

  /// A measure reading the numeric [column]; see [ColumnMeasure].
  const factory Measure(String column, {String? label}) = ColumnMeasure;

  /// A measure computed by an expression; see [ExpressionMeasure].
  factory Measure.expression(
    String source, {
    String? id,
    String? label,
    FunctionRegistry? functions,
  }) = ExpressionMeasure;

  /// Unique identifier: the column name, or the expression source.
  String get id;

  /// Human readable name, without reference to any fact table.
  String get label;

  /// An explicitly given label, otherwise one derived from [facts] (the
  /// column's label for a [ColumnMeasure]).
  String labelFor(FactTable facts);

  /// The fact table columns the measure reads.
  Set<String> get columns;

  @override
  bool operator ==(Object other) => other is Measure && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Measure($id)';
}

/// A measure that is one numeric column of the [FactTable].
final class ColumnMeasure extends Measure {
  const ColumnMeasure(this.column, {this._label}) : super._();

  /// Name of the [FactTable] column, which must have a numeric `ColumnType`.
  final String column;
  final String? _label;

  @override
  String get id => column;

  @override
  String get label => _label ?? column;

  @override
  String labelFor(FactTable facts) =>
      _label ?? facts.findColumn(column)?.label ?? column;

  @override
  Set<String> get columns => {column};
}

/// A measure computed per fact by a numeric expression over the columns,
/// e.g. `quantity * unit_price * (1 - coalesce(discount, 0))`.
///
/// The value is computed once per fact table (on first use) and then read
/// like a stored column, so aggregating it costs the same as a plain
/// column. A parse error is thrown by the constructor; a type error (an
/// unknown column, a text result) surfaces when the measure first meets
/// the fact table, as an [ExpressionError] — validate beforehand with
/// [Expression.validate] in `ExpressionScope.ofFacts(facts)` and
/// `expected: ExprType.number`.
final class ExpressionMeasure extends Measure {
  ExpressionMeasure(this.source, {this._id, this._label, this.functions})
    : expression = Expression.parse(source),
      super._();

  final String source;
  final Expression expression;

  /// Functions beyond the built-in ones the expression may call.
  final FunctionRegistry? functions;
  final String? _id;
  final String? _label;

  /// [source] unless an id was given.
  @override
  String get id => _id ?? source;

  @override
  String get label => _label ?? source;

  @override
  String labelFor(FactTable facts) => label;

  @override
  Set<String> get columns => expression.names;
}
