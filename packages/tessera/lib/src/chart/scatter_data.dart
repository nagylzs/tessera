import '../cube/aggregate.dart';
import '../cube/cube.dart';
import '../cube/cube_layout.dart';
import '../cube/cube_spec.dart';
import '../cube/dimension_path.dart';
import '../cube/filter.dart';
import '../facts/dimension.dart';
import '../facts/fact_table.dart';
import '../facts/measure.dart';
import '../l10n/l10n_en.dart';
import '../l10n/tessera_strings.dart';
import 'chart_data.dart';
import 'chart_entries.dart';

/// One point of a scatter chart: a group (two aggregates against each
/// other) or a single fact (two measures).
final class ScatterPoint {
  const ScatterPoint({
    required this.x,
    required this.y,
    required this.label,
    this.path,
    this.row,
    this.factCount = 1,
  });

  final double x;
  final double y;

  /// The group's label, or the fact's [ScatterData.pointLabel] dimension
  /// value formatted (empty when the data has no point labels).
  final String label;

  /// The group's path on its axis; `null` for a fact.
  final DimensionPath? path;

  /// The fact's row index in the table; `null` for a group.
  final int? row;

  /// Facts behind the point; `1` for a fact.
  final int factCount;

  @override
  String toString() => 'ScatterPoint($label: $x, $y)';
}

/// One series of a scatter chart — a colour or marker group.
final class ScatterSeries {
  const ScatterSeries({
    required this.path,
    required this.label,
    required this.value,
    required this.points,
  });

  /// The group's path on its axis; [DimensionPath.root] for the summary,
  /// or for the single series of data without a series dimension. `null`
  /// for a per-fact series (there is no axis).
  final DimensionPath? path;
  final String label;

  /// The group's raw dimension value; `null` for the empty group, the
  /// summary and the single series.
  final Object? value;

  /// Points with both coordinates present, in category or row order.
  final List<ScatterPoint> points;

  @override
  String toString() => 'ScatterSeries($label, ${points.length} points)';
}

/// Chart-ready scatter data: (x, y) pairs in one or more series, without a
/// category axis.
///
/// Two flavours. Per group — [fromLayout], [fromFacts], [fromCell] — one
/// point per group with two aggregates as coordinates ("unit price against
/// quantity per product, coloured by region"), read from a layout's cells
/// like [ChartData]. Per fact — [ofFacts] — one point per table row with
/// two measures as coordinates, optionally restricted to the rows behind a
/// cell ([CubeCell.factRows]). Points with a missing coordinate are left
/// out.
final class ScatterData {
  const ScatterData({
    required this.xLabel,
    required this.yLabel,
    required this.series,
    this.xAggregate,
    this.yAggregate,
    this.xMeasure,
    this.yMeasure,
    this.pointLabel,
  });

  final String xLabel;
  final String yLabel;
  final List<ScatterSeries> series;

  /// The aggregates behind the coordinates of per-group data.
  final Aggregate? xAggregate;
  final Aggregate? yAggregate;

  /// The measures behind the coordinates of per-fact data.
  final Measure? xMeasure;
  final Measure? yMeasure;

  /// The dimension labelling the points of per-fact data.
  final Dimension? pointLabel;

  /// Every point of every series.
  Iterable<ScatterPoint> get points => series.expand((s) => s.points);

  /// One point per selected row entry — [x] against [y] — in one series per
  /// selected column entry. Both aggregates must be in the spec.
  /// [transpose] takes the points from the columns and the series from the
  /// rows instead. A layout without column dimensions gives one series.
  factory ScatterData.fromLayout(
    CubeLayout layout, {
    required Aggregate x,
    required Aggregate y,
    ChartEntries points = ChartEntries.leaves,
    ChartEntries series = ChartEntries.leaves,
    bool transpose = false,
    TesseraStrings strings = const TesseraStringsEn(),
  }) {
    final xs = ChartData.fromLayout(
      layout,
      aggregate: x,
      rows: transpose ? series : points,
      columns: transpose ? points : series,
      transpose: transpose,
      strings: strings,
    );
    final ys = ChartData.fromLayout(
      layout,
      aggregate: y,
      rows: transpose ? series : points,
      columns: transpose ? points : series,
      transpose: transpose,
      strings: strings,
    );
    final seriesAxis = transpose ? layout.spec.rows : layout.spec.columns;
    return ScatterData(
      xLabel: xs.aggregateLabel,
      yLabel: ys.aggregateLabel,
      xAggregate: x,
      yAggregate: y,
      series: [
        for (var s = 0; s < xs.series.length; s++)
          ScatterSeries(
            path: xs.series[s].path,
            label: xs.series[s].path.isRoot && seriesAxis.isEmpty
                ? '' // the only series: nothing to distinguish it from
                : xs.series[s].label,
            value: xs.series[s].value,
            points: [
              for (var i = 0; i < xs.categories.length; i++)
                if ((xs.series[s].values[i], ys.series[s].values[i]) case (
                  final px?,
                  final py?,
                ))
                  ScatterPoint(
                    x: px,
                    y: py,
                    label: xs.categories[i].label,
                    path: xs.categories[i].path,
                    factCount: _cellOf(
                      layout,
                      xs.categories[i].path,
                      xs.series[s].path,
                      transpose,
                    ).factCount,
                  ),
            ],
          ),
      ],
    );
  }

  /// One point per distinct value of [points] in [facts] (after [filter]),
  /// in one series per distinct value of [series] — through a cube with
  /// [points] on the rows and [series] on the columns.
  factory ScatterData.fromFacts(
    FactTable facts, {
    required Dimension points,
    Dimension? series,
    required Aggregate x,
    required Aggregate y,
    FactFilter? filter,
    AxisSort? sort,
    AxisSort? seriesSort,
    TesseraStrings strings = const TesseraStringsEn(),
  }) {
    final cube = Cube(
      facts: facts,
      spec: CubeSpec(
        rows: CubeAxis(dimensions: [AxisDimension(points, sort: sort)]),
        columns: series == null
            ? const CubeAxis()
            : CubeAxis(dimensions: [AxisDimension(series, sort: seriesSort)]),
        aggregates: [x, y],
        filter: filter,
      ),
    );
    return ScatterData.fromLayout(cube.layout, x: x, y: y, strings: strings);
  }

  /// The facts behind [cell] broken down by [points] (and [series]), with
  /// [x] against [y] — a drill-down.
  factory ScatterData.fromCell(
    CubeLayout layout,
    CubeCell cell, {
    required Dimension points,
    Dimension? series,
    required Aggregate x,
    required Aggregate y,
    AxisSort? sort,
    AxisSort? seriesSort,
    TesseraStrings strings = const TesseraStringsEn(),
  }) => ScatterData.fromFacts(
    layout.facts,
    points: points,
    series: series,
    x: x,
    y: y,
    filter: cellFilter(layout, cell),
    sort: sort,
    seriesSort: seriesSort,
    strings: strings,
  );

  /// One point per fact: [x] against [y] for every row of [facts] — or of
  /// [rows] when given (e.g. [CubeCell.factRows]) — that passes [filter],
  /// in one series per value of [series] (ordered by
  /// [Dimension.compareValues], the empty group first) or a single unnamed
  /// series. [pointLabel] names each point by a dimension value. At most
  /// [limit] points are taken, in row order.
  factory ScatterData.ofFacts(
    FactTable facts, {
    required Measure x,
    required Measure y,
    Dimension? series,
    Dimension? pointLabel,
    FactFilter? filter,
    Iterable<int>? rows,
    int? limit,
    TesseraStrings strings = const TesseraStringsEn(),
  }) {
    final pass = filter?.compile(facts);
    final bySeries = <Object?, List<ScatterPoint>>{};
    var taken = 0;
    for (final row in rows ?? Iterable<int>.generate(facts.rowCount)) {
      if (limit != null && taken >= limit) break;
      if (pass != null && !pass(row)) continue;
      final px = facts.measureValue(row, x);
      final py = facts.measureValue(row, y);
      if (px == null || py == null) continue;
      taken++;
      final key = series == null ? null : facts.dimensionValue(row, series);
      bySeries
          .putIfAbsent(key, () => [])
          .add(
            ScatterPoint(
              x: px,
              y: py,
              label: pointLabel == null
                  ? ''
                  : strings.formatValue(
                      pointLabel,
                      facts.dimensionValue(row, pointLabel),
                    ),
              row: row,
            ),
          );
    }
    final keys = bySeries.keys.toList();
    if (series != null) keys.sort(series.compareValues);
    return ScatterData(
      xLabel: x.labelFor(facts),
      yLabel: y.labelFor(facts),
      xMeasure: x,
      yMeasure: y,
      pointLabel: pointLabel,
      series: [
        for (final key in keys)
          ScatterSeries(
            path: null,
            label: series == null
                ? ''
                : key == null
                ? strings.emptyGroup
                : strings.formatValue(series, key),
            value: key,
            points: bySeries[key]!,
          ),
      ],
    );
  }

  @override
  String toString() =>
      'ScatterData($xLabel × $yLabel: ${series.length} series, '
      '${points.length} points)';
}

/// The cell at a point's category × series (the entries are visible, so it
/// exists).
CubeCell _cellOf(
  CubeLayout layout,
  DimensionPath point,
  DimensionPath series,
  bool transpose,
) =>
    transpose ? layout.cellFor(series, point)! : layout.cellFor(point, series)!;
