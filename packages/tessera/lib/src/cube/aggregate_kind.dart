import '../facts/dimension.dart';
import '../facts/measure.dart';
import 'aggregate.dart';

/// The built-in aggregate functions, as offered by the aggregate picker.
/// Display names come from `TesseraStrings.aggregateKindLabel`.
enum AggregateKind {
  sum,
  average,
  min,
  max,
  countNonNull,
  distinctCount,
  count;

  /// Whether [build] needs a [Measure].
  bool get needsMeasure => switch (this) {
    sum || average || min || max || countNonNull => true,
    distinctCount || count => false,
  };

  /// Whether [build] needs a [Dimension].
  bool get needsDimension => this == distinctCount;

  Aggregate build({Measure? measure, Dimension? dimension}) => switch (this) {
    sum => Aggregate.sum(measure!),
    average => Aggregate.average(measure!),
    min => Aggregate.min(measure!),
    max => Aggregate.max(measure!),
    countNonNull => Aggregate.countNonNull(measure!),
    distinctCount => Aggregate.distinctCount(dimension!),
    count => Aggregate.count,
  };
}
