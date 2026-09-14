import 'dart:math' as math;
import 'dart:typed_data';

import '../expr/checker.dart';
import '../expr/compiler.dart';
import '../expr/expr_type.dart';
import '../expr/expression.dart';
import '../expr/functions.dart';
import '../facts/dimension.dart';
import '../facts/fact_table.dart';
import '../facts/measure.dart';

/// Running state of one [Aggregate] over a subset of facts.
///
/// Accumulators are the unit of work of the cube's aggregation pass: one is
/// created per (cell, aggregate), fed every fact of the cell with [add], and
/// parent cells are obtained by [merge]-ing their children instead of
/// rescanning. That is why `average` carries sum + count rather than a
/// running mean.
abstract class AggregateAccumulator<R> {
  void add(FactTable facts, int row);

  void merge(covariant AggregateAccumulator<R> other);

  /// `null` when nothing meaningful was accumulated (no facts, or only
  /// missing measure values).
  R? get result;
}

/// A summary computed for every [CubeCell]: sum, count, average, …
///
/// Aggregates are value objects identified by [id]. The built-in ones are
/// exposed as static constructors; implement this class for custom ones.
abstract class Aggregate<R> {
  const Aggregate();

  /// Unique identifier, e.g. `sum(total)`.
  String get id;

  /// Human readable name, without reference to any fact table.
  String get label;

  /// Human readable name for use with [facts]; built-in aggregates use the
  /// column labels of the table (see [Measure.labelFor]).
  String labelFor(FactTable facts) => label;

  AggregateAccumulator<R> createAccumulator();

  static SumAggregate sum(Measure measure) => SumAggregate(measure);
  static AverageAggregate average(Measure measure) => AverageAggregate(measure);
  static MinAggregate min(Measure measure) => MinAggregate(measure);
  static MaxAggregate max(Measure measure) => MaxAggregate(measure);

  /// Number of facts in the cell, regardless of any measure.
  static const CountAggregate count = CountAggregate();

  /// Number of facts whose [measure] is not null.
  static CountNonNullAggregate countNonNull(Measure measure) =>
      CountNonNullAggregate(measure);

  /// Sample standard deviation (n − 1 denominator, Excel's `STDEV.S`).
  static StdDevAggregate stdDev(Measure measure) => StdDevAggregate(measure);

  /// Population standard deviation (n denominator, Excel's `STDEV.P`).
  static StdDevPopulationAggregate stdDevPopulation(Measure measure) =>
      StdDevPopulationAggregate(measure);

  /// Sample variance (n − 1 denominator, Excel's `VAR.S`).
  static VarianceAggregate variance(Measure measure) =>
      VarianceAggregate(measure);

  /// Population variance (n denominator, Excel's `VAR.P`).
  static VariancePopulationAggregate variancePopulation(Measure measure) =>
      VariancePopulationAggregate(measure);

  static DistinctCountAggregate distinctCount(Dimension dimension) =>
      DistinctCountAggregate(dimension);

  /// A number computed per cell from other aggregates by a cell formula,
  /// e.g. `sum(total) / count`; see [ExpressionAggregate].
  static ExpressionAggregate expression(
    String source, {
    String? id,
    String? label,
    FunctionRegistry? functions,
  }) => ExpressionAggregate(source, id: id, label: label, functions: functions);

  @override
  bool operator ==(Object other) => other is Aggregate && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => id;
}

/// Base for aggregates over a single [Measure].
abstract class MeasureAggregate<R> extends Aggregate<R> {
  const MeasureAggregate(this.measure);

  final Measure measure;

  /// Function name used to build [id] and [label], e.g. `sum`.
  String get function;

  @override
  String get id => '$function(${measure.id})';

  @override
  String get label => '$function of ${measure.label}';

  @override
  String labelFor(FactTable facts) => '$function of ${measure.labelFor(facts)}';
}

/// Σ of non-null values. `null` if every value was missing.
final class SumAggregate extends MeasureAggregate<double> {
  const SumAggregate(super.measure);

  @override
  String get function => 'sum';

  @override
  AggregateAccumulator<double> createAccumulator() => _SumAccumulator(measure);
}

/// Mean of non-null values. `null` if every value was missing.
final class AverageAggregate extends MeasureAggregate<double> {
  const AverageAggregate(super.measure);

  @override
  String get function => 'avg';

  @override
  AggregateAccumulator<double> createAccumulator() =>
      _AverageAccumulator(measure);
}

final class MinAggregate extends MeasureAggregate<double> {
  const MinAggregate(super.measure);

  @override
  String get function => 'min';

  @override
  AggregateAccumulator<double> createAccumulator() =>
      _ExtremumAccumulator(measure, min: true);
}

final class MaxAggregate extends MeasureAggregate<double> {
  const MaxAggregate(super.measure);

  @override
  String get function => 'max';

  @override
  AggregateAccumulator<double> createAccumulator() =>
      _ExtremumAccumulator(measure, min: false);
}

final class CountNonNullAggregate extends MeasureAggregate<int> {
  const CountNonNullAggregate(super.measure);

  @override
  String get function => 'count';

  @override
  AggregateAccumulator<int> createAccumulator() =>
      _CountNonNullAccumulator(measure);
}

/// Base of the variance family: one accumulator (count, mean, M2 — Welford
/// on [AggregateAccumulator.add], Chan's parallel formula on `merge`, so
/// parents merge children exactly and large means do not cancel), four
/// results.
abstract class VarianceFamilyAggregate extends MeasureAggregate<double> {
  const VarianceFamilyAggregate(super.measure);

  /// Whether the denominator is n − 1 (sample) or n (population).
  bool get isSample;

  /// Whether the result is the square root of the variance.
  bool get isStdDev;

  @override
  AggregateAccumulator<double> createAccumulator() =>
      _VarianceAccumulator(measure, sample: isSample, root: isStdDev);
}

/// Sample standard deviation of non-null values; `null` with fewer than
/// two values.
final class StdDevAggregate extends VarianceFamilyAggregate {
  const StdDevAggregate(super.measure);

  @override
  String get function => 'stdev';
  @override
  bool get isSample => true;
  @override
  bool get isStdDev => true;
}

/// Population standard deviation of non-null values; `null` with no
/// value.
final class StdDevPopulationAggregate extends VarianceFamilyAggregate {
  const StdDevPopulationAggregate(super.measure);

  @override
  String get function => 'stdevp';
  @override
  bool get isSample => false;
  @override
  bool get isStdDev => true;
}

/// Sample variance of non-null values; `null` with fewer than two values.
final class VarianceAggregate extends VarianceFamilyAggregate {
  const VarianceAggregate(super.measure);

  @override
  String get function => 'var';
  @override
  bool get isSample => true;
  @override
  bool get isStdDev => false;
}

/// Population variance of non-null values; `null` with no value.
final class VariancePopulationAggregate extends VarianceFamilyAggregate {
  const VariancePopulationAggregate(super.measure);

  @override
  String get function => 'varp';
  @override
  bool get isSample => false;
  @override
  bool get isStdDev => false;
}

/// Number of facts. Never `null`; `0` for an empty cell.
final class CountAggregate extends Aggregate<int> {
  const CountAggregate();

  @override
  String get id => 'count';

  @override
  String get label => 'count';

  @override
  AggregateAccumulator<int> createAccumulator() => _CountAccumulator();
}

/// Number of distinct non-null values of a dimension (like SQL
/// `COUNT(DISTINCT …)`). Its accumulator has to carry the value set, so
/// merging is not O(1); it is still exact.
final class DistinctCountAggregate extends Aggregate<int> {
  const DistinctCountAggregate(this.dimension);

  final Dimension dimension;

  @override
  String get id => 'distinct(${dimension.id})';

  @override
  String get label => 'distinct ${dimension.label}';

  @override
  String labelFor(FactTable facts) => 'distinct ${dimension.labelFor(facts)}';

  @override
  AggregateAccumulator<int> createAccumulator() =>
      _DistinctCountAccumulator(dimension);
}

final class _SumAccumulator extends AggregateAccumulator<double> {
  _SumAccumulator(this.measure);
  final Measure measure;
  double sum = 0;
  bool hasValue = false;

  @override
  void add(FactTable facts, int row) {
    final v = facts.measureValue(row, measure);
    if (v != null) {
      sum += v;
      hasValue = true;
    }
  }

  @override
  void merge(_SumAccumulator other) {
    sum += other.sum;
    hasValue = hasValue || other.hasValue;
  }

  @override
  double? get result => hasValue ? sum : null;
}

final class _AverageAccumulator extends AggregateAccumulator<double> {
  _AverageAccumulator(this.measure);
  final Measure measure;
  double sum = 0;
  int count = 0;

  @override
  void add(FactTable facts, int row) {
    final v = facts.measureValue(row, measure);
    if (v != null) {
      sum += v;
      count++;
    }
  }

  @override
  void merge(_AverageAccumulator other) {
    sum += other.sum;
    count += other.count;
  }

  @override
  double? get result => count == 0 ? null : sum / count;
}

final class _ExtremumAccumulator extends AggregateAccumulator<double> {
  _ExtremumAccumulator(this.measure, {required this.min});
  final Measure measure;
  final bool min;
  double? value;

  @override
  void add(FactTable facts, int row) {
    final v = facts.measureValue(row, measure);
    if (v != null) _take(v);
  }

  void _take(double v) {
    final current = value;
    if (current == null || (min ? v < current : v > current)) value = v;
  }

  @override
  void merge(_ExtremumAccumulator other) {
    final v = other.value;
    if (v != null) _take(v);
  }

  @override
  double? get result => value;
}

final class _VarianceAccumulator extends AggregateAccumulator<double> {
  _VarianceAccumulator(
    this.measure, {
    required this.sample,
    required this.root,
  });
  final Measure measure;
  final bool sample;
  final bool root;
  int count = 0;
  double mean = 0;

  /// Sum of squared deviations from the running mean.
  double m2 = 0;

  @override
  void add(FactTable facts, int row) {
    final v = facts.measureValue(row, measure);
    if (v == null) return;
    count++;
    final delta = v - mean;
    mean += delta / count;
    m2 += delta * (v - mean);
  }

  @override
  void merge(_VarianceAccumulator other) {
    if (other.count == 0) return;
    if (count == 0) {
      count = other.count;
      mean = other.mean;
      m2 = other.m2;
      return;
    }
    final n = count + other.count;
    final delta = other.mean - mean;
    m2 += other.m2 + delta * delta * count * other.count / n;
    mean += delta * other.count / n;
    count = n;
  }

  @override
  double? get result {
    final denominator = sample ? count - 1 : count;
    if (denominator < 1) return null;
    final variance = m2 / denominator;
    return root ? math.sqrt(variance) : variance;
  }
}

final class _CountNonNullAccumulator extends AggregateAccumulator<int> {
  _CountNonNullAccumulator(this.measure);
  final Measure measure;
  int count = 0;

  @override
  void add(FactTable facts, int row) {
    if (facts.measureValue(row, measure) != null) count++;
  }

  @override
  void merge(_CountNonNullAccumulator other) => count += other.count;

  @override
  int get result => count;
}

final class _CountAccumulator extends AggregateAccumulator<int> {
  int count = 0;

  @override
  void add(FactTable facts, int row) => count++;

  @override
  void merge(_CountAccumulator other) => count += other.count;

  @override
  int get result => count;
}

final class _DistinctCountAccumulator extends AggregateAccumulator<int> {
  _DistinctCountAccumulator(this.dimension);
  final Dimension dimension;
  final values = <Object?>{};

  @override
  void add(FactTable facts, int row) {
    final v = facts.dimensionValue(row, dimension);
    if (v != null) values.add(v);
  }

  @override
  void merge(_DistinctCountAccumulator other) => values.addAll(other.values);

  @override
  int get result => values.length;
}

/// An aggregate that is not accumulated over facts but computed per cell
/// from the results of other aggregates ([dependencies]) once accumulation
/// is done: a ratio, a difference, a rounded value.
///
/// The engine accumulates the dependencies (whether or not the spec lists
/// them) and calls [compute] when the cell's value is read.
/// [createAccumulator] is never called and throws.
abstract class DerivedAggregate<R> extends Aggregate<R> {
  const DerivedAggregate();

  /// The aggregates whose results [compute] needs.
  List<Aggregate> get dependencies;

  /// The value for a cell; [resultOf] returns the cell's result of any of
  /// the [dependencies] (`null` for an empty cell).
  R? compute(Object? Function(Aggregate aggregate) resultOf);

  /// Called by the engine before a layout is computed against [facts];
  /// throws when the aggregate cannot be evaluated there.
  void prepare(FactTable facts) {}

  @override
  AggregateAccumulator<R> createAccumulator() =>
      throw UnsupportedError('$id is derived, not accumulated');
}

/// A number computed per cell by a formula over aggregates of the same
/// cell: `sum(total) / sum(quantity)`, `round(sum(total) / count, 2)`,
/// `count(discount) / count * 100`.
///
/// The formula is an expression in cell scope (see
/// [ExpressionScope.cells]): `sum(col)`, `avg(col)`, `min(col)`,
/// `max(col)`, `count` (facts), `count(col)` (non-empty values) and
/// `distinct(col)` are the aggregate references; the built-in functions
/// and arithmetic apply. The result is `null` when a referenced aggregate
/// is `null` (an empty cell) or a division by zero occurs.
final class ExpressionAggregate extends DerivedAggregate<double> {
  ExpressionAggregate(this.source, {this._id, this._label, this.functions})
    : expression = Expression.parse(source);

  final String source;
  final Expression expression;

  /// Functions beyond the built-in ones the formula may call.
  final FunctionRegistry? functions;
  final String? _id;
  final String? _label;

  /// [source] unless an id was given.
  @override
  String get id => _id ?? source;

  /// The label given at construction, or `null` when [label] is [source].
  String? get explicitLabel => _label;

  @override
  String get label => _label ?? source;

  /// The aggregates the formula refers to, by shape (`sum(qty)`,
  /// `avg(qty * price)`, `count`, …), in first-use order. Known without a
  /// fact table; [prepare] checks them against one.
  @override
  late final List<Aggregate> dependencies = List.unmodifiable(
    aggregateReferences(expression.root, functions: functions),
  );

  FactTable? _preparedFor;
  NumberFn? _compiled;
  late final Float64List _slot = Float64List(dependencies.length);

  /// Type-checks the formula against the columns of [facts] and compiles
  /// it; throws [ExpressionError] when a referenced column is missing or
  /// an argument has the wrong type. The engine calls this before every
  /// layout; [compute] requires it.
  @override
  void prepare(FactTable facts) {
    if (identical(facts, _preparedFor)) return;
    final checked = expression.check(
      ExpressionScope.cellsOf(facts, functions: functions),
      expected: ExprType.number,
    );
    _compiled = compileExpression(
      checked,
      CellBindings(dependencies, _slot),
    ).asNumber;
    _preparedFor = facts;
  }

  @override
  double? compute(Object? Function(Aggregate aggregate) resultOf) {
    final f = _compiled;
    if (f == null) throw StateError('$id: prepare(facts) was not called');
    final slot = _slot;
    for (var k = 0; k < dependencies.length; k++) {
      final v = resultOf(dependencies[k]);
      slot[k] = v is num ? v.toDouble() : double.nan;
    }
    final r = f(0);
    return r.isNaN ? null : r;
  }
}
