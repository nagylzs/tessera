import '../facts/dimension.dart';
import 'aggregate.dart';
import 'filter.dart';

enum SortBy {
  /// Order groups by their dimension value ([Dimension.compareValues]).
  value,

  /// Order groups by an aggregate of the facts they contain ("top countries
  /// by revenue").
  aggregate,
}

enum SortDirection { ascending, descending }

/// Where the empty group (`null` value) is placed among its siblings.
enum NullPosition { first, last }

/// Where the summary row/column of an axis is placed.
enum SummaryPosition { start, end, hidden }

/// Ordering of the groups produced by one [AxisDimension].
final class AxisSort {
  const AxisSort({
    this.by = SortBy.value,
    this.aggregate,
    this.direction = SortDirection.ascending,
    this.nulls = NullPosition.first,
  }) : assert(
         by != SortBy.aggregate || aggregate != null,
         'SortBy.aggregate requires an aggregate',
       );

  final SortBy by;

  /// Required when [by] is [SortBy.aggregate]; must be one of
  /// [CubeSpec.aggregates].
  final Aggregate? aggregate;

  final SortDirection direction;
  final NullPosition nulls;
}

/// One level of a [CubeAxis].
final class AxisDimension {
  const AxisDimension(this.dimension, {this.sort = const AxisSort()});

  final Dimension dimension;
  final AxisSort sort;
}

/// The hierarchy of one side of the cube: an ordered list of dimensions.
///
/// `[region, country]` groups facts by region and, within each region, by
/// country. An empty axis has a single group, the summary.
final class CubeAxis {
  const CubeAxis({
    this.dimensions = const [],
    this.summaryPosition = SummaryPosition.end,
  });

  /// Shorthand for an axis with default sorting.
  CubeAxis.of(
    List<Dimension> dimensions, {
    SummaryPosition summaryPosition = SummaryPosition.end,
  }) : this(
         dimensions: [for (final d in dimensions) AxisDimension(d)],
         summaryPosition: summaryPosition,
       );

  final List<AxisDimension> dimensions;
  final SummaryPosition summaryPosition;

  /// Number of levels below the summary.
  int get depth => dimensions.length;

  bool get isEmpty => dimensions.isEmpty;

  bool contains(Dimension dimension) =>
      dimensions.any((d) => d.dimension == dimension);

  /// The dimension at [depth] (1-based, so `dimensionAt(1)` is the first
  /// level) or `null` beyond the axis.
  Dimension? dimensionAt(int depth) => depth >= 1 && depth <= dimensions.length
      ? dimensions[depth - 1].dimension
      : null;

  CubeAxis copyWith({
    List<AxisDimension>? dimensions,
    SummaryPosition? summaryPosition,
  }) => CubeAxis(
    dimensions: dimensions ?? this.dimensions,
    summaryPosition: summaryPosition ?? this.summaryPosition,
  );
}

/// Everything that defines a [Cube] except the facts and the expansion
/// state: the two axes, the aggregates to compute and an optional filter.
///
/// Immutable. A dimension may appear on at most one axis; violating this
/// throws [ArgumentError].
final class CubeSpec {
  CubeSpec({
    this.rows = const CubeAxis(),
    this.columns = const CubeAxis(),
    this.aggregates = const [Aggregate.count],
    this.filter,
  }) {
    for (final d in rows.dimensions) {
      if (columns.contains(d.dimension)) {
        throw ArgumentError.value(
          d.dimension.id,
          'rows',
          'dimension appears on both axes',
        );
      }
    }
    for (final axis in [rows, columns]) {
      final seen = <Dimension>{};
      for (final d in axis.dimensions) {
        if (!seen.add(d.dimension)) {
          throw ArgumentError.value(
            d.dimension.id,
            'dimensions',
            'dimension appears twice on the same axis',
          );
        }
      }
    }
  }

  final CubeAxis rows;
  final CubeAxis columns;

  /// Aggregates computed for every cell. Must be non-empty for the cube to
  /// be useful, but an empty list is allowed (only fact counts are then
  /// available).
  final List<Aggregate> aggregates;

  /// Facts that fail the filter are ignored entirely.
  final FactFilter? filter;

  CubeSpec copyWith({
    CubeAxis? rows,
    CubeAxis? columns,
    List<Aggregate>? aggregates,
    FactFilter? Function()? filter,
  }) => CubeSpec(
    rows: rows ?? this.rows,
    columns: columns ?? this.columns,
    aggregates: aggregates ?? this.aggregates,
    filter: filter != null ? filter() : this.filter,
  );
}
