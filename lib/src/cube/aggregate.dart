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
  Accumulator<double> createAccumulator() => throw UnimplementedError();
}

/// Mean of non-null values. `null` if every value was missing.
final class AverageAggregate extends MeasureAggregate<double> {
  const AverageAggregate(super.measure);

  @override
  String get function => 'avg';

  @override
  Accumulator<double> createAccumulator() => throw UnimplementedError();
}

final class MinAggregate extends MeasureAggregate<double> {
  const MinAggregate(super.measure);

  @override
  String get function => 'min';

  @override
  Accumulator<double> createAccumulator() => throw UnimplementedError();
}

final class MaxAggregate extends MeasureAggregate<double> {
  const MaxAggregate(super.measure);

  @override
  String get function => 'max';

  @override
  Accumulator<double> createAccumulator() => throw UnimplementedError();
}

final class CountNonNullAggregate extends MeasureAggregate<int> {
  const CountNonNullAggregate(super.measure);

  @override
  String get function => 'count';

  @override
  Accumulator<int> createAccumulator() => throw UnimplementedError();
}

/// Number of facts. Never `null`; `0` for an empty cell.
final class CountAggregate extends Aggregate<int> {
  const CountAggregate();

  @override
  String get id => 'count';

  @override
  String get label => 'count';

  @override
  Accumulator<int> createAccumulator() => throw UnimplementedError();
}

/// Number of distinct values of a dimension. Note that unlike the other
/// built-ins its accumulator has to carry the value set, so merging is not
/// O(1); it is still exact.
final class DistinctCountAggregate extends Aggregate<int> {
  const DistinctCountAggregate(this.dimension);

  final Dimension dimension;

  @override
  String get id => 'distinct(${dimension.id})';

  @override
  String get label => 'distinct ${dimension.label}';

  @override
  Accumulator<int> createAccumulator() => throw UnimplementedError();
}
