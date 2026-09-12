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
abstract class Accumulator<R> {
  void add(FactTable facts, int row);

  void merge(covariant Accumulator<R> other);

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

  String get label;

  Accumulator<R> createAccumulator();

  static SumAggregate sum(Measure measure) => SumAggregate(measure);
  static AverageAggregate average(Measure measure) => AverageAggregate(measure);
  static MinAggregate min(Measure measure) => MinAggregate(measure);
  static MaxAggregate max(Measure measure) => MaxAggregate(measure);

  /// Number of facts in the cell, regardless of any measure.
  static const CountAggregate count = CountAggregate();

  /// Number of facts whose [measure] is not null.
  static CountNonNullAggregate countNonNull(Measure measure) =>
      CountNonNullAggregate(measure);

  static DistinctCountAggregate distinctCount(Dimension dimension) =>
      DistinctCountAggregate(dimension);

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
}

/// Σ of non-null values. `null` if every value was missing.
final class SumAggregate extends MeasureAggregate<double> {
  const SumAggregate(super.measure);

  @override
  String get function => 'sum';

  @override
  Accumulator<double> createAccumulator() => _SumAccumulator(measure);
}

/// Mean of non-null values. `null` if every value was missing.
final class AverageAggregate extends MeasureAggregate<double> {
  const AverageAggregate(super.measure);

  @override
  String get function => 'avg';

  @override
  Accumulator<double> createAccumulator() => _AverageAccumulator(measure);
}

final class MinAggregate extends MeasureAggregate<double> {
  const MinAggregate(super.measure);

  @override
  String get function => 'min';

  @override
  Accumulator<double> createAccumulator() =>
      _ExtremumAccumulator(measure, min: true);
}

final class MaxAggregate extends MeasureAggregate<double> {
  const MaxAggregate(super.measure);

  @override
  String get function => 'max';

  @override
  Accumulator<double> createAccumulator() =>
      _ExtremumAccumulator(measure, min: false);
}

final class CountNonNullAggregate extends MeasureAggregate<int> {
  const CountNonNullAggregate(super.measure);

  @override
  String get function => 'count';

  @override
  Accumulator<int> createAccumulator() => _CountNonNullAccumulator(measure);
}

/// Number of facts. Never `null`; `0` for an empty cell.
final class CountAggregate extends Aggregate<int> {
  const CountAggregate();

  @override
  String get id => 'count';

  @override
  String get label => 'count';

  @override
  Accumulator<int> createAccumulator() => _CountAccumulator();
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
  Accumulator<int> createAccumulator() => _DistinctCountAccumulator(dimension);
}

final class _SumAccumulator extends Accumulator<double> {
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

final class _AverageAccumulator extends Accumulator<double> {
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

final class _ExtremumAccumulator extends Accumulator<double> {
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

final class _CountNonNullAccumulator extends Accumulator<int> {
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

final class _CountAccumulator extends Accumulator<int> {
  int count = 0;

  @override
  void add(FactTable facts, int row) => count++;

  @override
  void merge(_CountAccumulator other) => count += other.count;

  @override
  int get result => count;
}

final class _DistinctCountAccumulator extends Accumulator<int> {
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
