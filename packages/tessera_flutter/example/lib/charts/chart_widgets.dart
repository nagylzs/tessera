import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:tessera_flutter/tessera_flutter.dart';

/// Draws the engine's chart-ready data with fl_chart. Pure adapters: every
/// function takes a [ChartData] / [ScatterData] and returns a widget, so an
/// app with another chart package replaces this file only.

/// How the X axis of a line chart is laid out — the payoff of the typed
/// category values.
enum LineAxis {
  /// Every category has a [ChartCategory.periodStart]: a real time axis.
  time,

  /// Every category value is a number of a plain column: a numeric axis.
  numeric,

  /// Otherwise: evenly spaced labels.
  categorical;

  static LineAxis of(ChartData data) {
    final cs = data.categories;
    if (cs.isEmpty) return categorical;
    if (cs.every((c) => c.periodStart != null)) return time;
    // a date part without a period start (a month on its own, a weekday)
    // is a number too, but an ordinal one: its months are named
    if (cs.every(
      (c) =>
          c.number != null &&
          c.path.entries.isNotEmpty &&
          c.path.last.dimension is! DatePartDimension,
    )) {
      return numeric;
    }
    return categorical;
  }
}

/// A palette of visually distinct hues, one per series, computed in OKLCH
/// like the grid's hue levels; the first hue is the theme's primary.
List<Color> seriesColors(BuildContext context, int count) {
  final scheme = Theme.of(context).colorScheme;
  final start = Oklch.fromArgb(scheme.primary.toARGB32()).hue;
  final dark = scheme.brightness == Brightness.dark;
  return [
    for (var i = 0; i < math.max(count, 1); i++)
      Color(
        Oklch(
          dark ? 0.72 : 0.58,
          0.14,
          (start + i * HueLevels.goldenAngle) % 360,
        ).toArgb(),
      ),
  ];
}

/// Short axis numbers: 1.2k, 3.4M, else the number itself.
String shortNumber(double v) {
  final a = v.abs();
  if (a >= 1e9) return '${(v / 1e9).toStringAsFixed(1)}G';
  if (a >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
  if (a >= 1e4) return '${(v / 1e3).toStringAsFixed(0)}k';
  if (a >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}k';
  return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

/// A round tick interval (1, 2, 5 × 10ⁿ) giving about [ticks] steps
/// over [range]; fl_chart's default crowds the axis on a tall chart.
double niceInterval(double range, {int ticks = 8}) {
  if (range <= 0 || !range.isFinite) return 1;
  final raw = range / ticks;
  final magnitude = math
      .pow(10, (math.log(raw) / math.ln10).floor())
      .toDouble();
  final unit = raw / magnitude;
  final step = unit <= 1
      ? 1.0
      : unit <= 2
      ? 2.0
      : unit <= 5
      ? 5.0
      : 10.0;
  return step * magnitude;
}

/// Ticks that fit an axis of [extent] pixels, one per [per] pixels.
int _ticksFor(double extent, {double per = 50}) =>
    (extent / per).floor().clamp(3, 8);

/// An axis over [values]: a [niceInterval] for its extent (including zero
/// unless [includeZero] is false) and the extent rounded outwards to whole
/// intervals, so the axis ends on labelled ticks instead of a max label
/// overlapping the tick below it.
class _AxisRange {
  factory _AxisRange(
    Iterable<double> values, {
    bool includeZero = true,
    int ticks = 8,
  }) {
    var lo = includeZero ? 0.0 : double.infinity;
    var hi = includeZero ? 0.0 : double.negativeInfinity;
    for (final v in values) {
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
    if (!lo.isFinite) lo = hi = 0;
    final interval = niceInterval(hi - lo, ticks: ticks);
    final min = (lo / interval).floorToDouble() * interval;
    final max = (hi / interval).ceilToDouble() * interval;
    return _AxisRange._(interval, min, max == min ? min + interval : max);
  }

  const _AxisRange._(this.interval, this.min, this.max);

  final double interval;
  final double min;
  final double max;
}

String _date(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// The legend fl_chart does not draw: a swatch per series.
Widget legend(List<String> labels, List<Color> colors) => Wrap(
  spacing: 12,
  runSpacing: 4,
  children: [
    for (var i = 0; i < labels.length; i++)
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 12, height: 12, color: colors[i]),
          const SizedBox(width: 4),
          Text(labels[i]),
        ],
      ),
  ],
);

/// Axis titles: numbers on the left every [leftInterval], [bottom] below.
/// fl_chart labels the axis ends as well, so the charts round their ranges
/// to whole intervals ([_AxisRange]) and the end labels fall on ticks.
FlTitlesData _titles({
  required Widget Function(double value, TitleMeta meta) bottom,
  required double leftInterval,
  double? bottomInterval,
  double bottomSize = 28,
  // the end labels of a numeric or time axis collide with their neighbours
  bool bottomEnds = true,
}) => FlTitlesData(
  topTitles: const AxisTitles(),
  rightTitles: const AxisTitles(),
  leftTitles: AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: 48,
      interval: leftInterval,
      getTitlesWidget: (v, meta) => SideTitleWidget(
        meta: meta,
        child: Text(shortNumber(v), style: const TextStyle(fontSize: 10)),
      ),
    ),
  ),
  bottomTitles: AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: bottomSize,
      interval: bottomInterval,
      minIncluded: bottomEnds,
      maxIncluded: bottomEnds,
      getTitlesWidget: bottom,
    ),
  ),
);

/// Grid lines on the same intervals as the titles.
FlGridData _grid(double horizontalInterval, {double? verticalInterval}) =>
    FlGridData(
      horizontalInterval: horizontalInterval,
      drawVerticalLine: verticalInterval != null,
      verticalInterval: verticalInterval,
    );

/// A bottom title for a numeric or time axis.
Widget _bottomTitle(String text, TitleMeta meta) => SideTitleWidget(
  meta: meta,
  child: Text(text, style: const TextStyle(fontSize: 10)),
);

/// Room on the right for a bottom title near the chart's edge.
const _rightMargin = EdgeInsets.only(right: 24);

/// A group's label with its ancestors when it sits deeper than the first
/// level (`leaves` under an expanded group): "Electronics › Africa", so two
/// "(empty)" groups — or 2024's Q1 and 2025's — can be told apart. The
/// engine labels a group by its own value only.
String pathLabel(
  BuildContext context,
  DimensionPath path,
  String own, {
  String separator = ' › ',
}) {
  if (path.length <= 1) return own;
  final strings = TesseraLocalizations.of(context);
  return path.entries
      .map(
        (e) => e.value == null
            ? strings.emptyGroup
            : strings.formatValue(e.dimension, e.value),
      )
      .join(separator);
}

/// [pathLabel] of every category.
List<String> categoryLabels(BuildContext context, ChartData data) => [
  for (final c in data.categories) pathLabel(context, c.path, c.label),
];

/// [pathLabel] of every series.
List<String> seriesLabels(BuildContext context, ChartData data) => [
  for (final s in data.series) pathLabel(context, s.path, s.label),
];

/// Whether any category sits below the first level.
bool _deep(ChartData data) => data.categories.any((c) => c.path.length > 1);

/// Height of the bottom titles: two lines for deep categories.
double _bottomSize(ChartData data) => _deep(data) ? 48 : 28;

/// Bottom titles naming the categories at integer positions, each within
/// its slot; a deep category's own label goes on a second line under its
/// ancestors ("Electronics › North America" would not fit).
Widget Function(double, TitleMeta) _categoryTitles(
  BuildContext context,
  ChartData data,
) {
  final strings = TesseraLocalizations.of(context);
  String of(DimensionValue e) => e.value == null
      ? strings.emptyGroup
      : strings.formatValue(e.dimension, e.value);
  final ancestorsOf = [
    for (final c in data.categories)
      c.path.length > 1
          ? c.path.entries.take(c.path.length - 1).map(of).join(' › ')
          : null,
  ];
  return (v, meta) {
    final i = v.round();
    if ((v - i).abs() > 1e-6 || i < 0 || i >= data.categories.length) {
      return const SizedBox.shrink();
    }
    final own = data.categories[i].label;
    final ancestors = ancestorsOf[i];
    Widget line(String text) => Text(
      text,
      style: const TextStyle(fontSize: 10),
      maxLines: 1,
      softWrap: false,
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
    );
    return SideTitleWidget(
      meta: meta,
      child: SizedBox(
        width: meta.parentAxisSize / data.categories.length,
        child: ancestors == null
            ? line(own)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [line(ancestors), line(own)],
              ),
      ),
    );
  };
}

/// Grouped or stacked bars: one group per category, one rod per series
/// (or one rod with a stack item per series).
Widget barChart(BuildContext context, ChartData data, {required bool stacked}) {
  final colors = seriesColors(context, data.series.length);
  final labels = categoryLabels(context, data);
  final series = seriesLabels(context, data);
  final tops = <double>[];
  final groups = <BarChartGroupData>[];
  // rod widths so the groups fill the chart, set once the width is known
  double rodWidth(double chartWidth) {
    final slots =
        data.categories.length * (stacked ? 2 : data.series.length + 1);
    return ((chartWidth - 60) / math.max(slots, 1)).clamp(3.0, 32.0);
  }

  for (var i = 0; i < data.categories.length; i++) {
    if (stacked) {
      // positives stack upwards from 0, negatives downwards
      var top = 0.0, bottom = 0.0;
      final items = <BarChartRodStackItem>[];
      for (var s = 0; s < data.series.length; s++) {
        final v = data.series[s].values[i];
        if (v == null || v == 0) continue;
        if (v > 0) {
          items.add(BarChartRodStackItem(top, top + v, colors[s]));
          top += v;
        } else {
          items.add(BarChartRodStackItem(bottom + v, bottom, colors[s]));
          bottom += v;
        }
      }
      tops.addAll([top, bottom]);
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              fromY: bottom,
              toY: top,
              rodStackItems: items,
              color: Colors.transparent,
              borderRadius: BorderRadius.zero,
            ),
          ],
        ),
      );
    } else {
      tops.addAll([for (final s in data.series) s.values[i] ?? 0]);
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            for (var s = 0; s < data.series.length; s++)
              BarChartRodData(
                toY: data.series[s].values[i] ?? 0,
                color: colors[s],
                borderRadius: BorderRadius.zero,
              ),
          ],
        ),
      );
    }
  }
  return Column(
    children: [
      Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final range = _AxisRange(
              tops,
              ticks: _ticksFor(constraints.maxHeight),
            );
            return BarChart(
              BarChartData(
                minY: range.min,
                maxY: range.max,
                barGroups: [
                  for (final g in groups)
                    g.copyWith(
                      barRods: [
                        for (final r in g.barRods)
                          r.copyWith(width: rodWidth(constraints.maxWidth)),
                      ],
                    ),
                ],
                titlesData: _titles(
                  bottom: _categoryTitles(context, data),
                  leftInterval: range.interval,
                  bottomSize: _bottomSize(data),
                ),
                gridData: _grid(range.interval),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, gi, rod, ri) {
                      final text = stacked
                          ? [
                              labels[group.x],
                              for (var s = 0; s < data.series.length; s++)
                                if (data.series[s].values[group.x]
                                    case final v?)
                                  '${series[s]}: ${shortNumber(v)}',
                            ].join('\n')
                          : '${labels[group.x]}\n${series[ri]}: '
                                '${shortNumber(data.series[ri].values[group.x] ?? 0)}';
                      return BarTooltipItem(
                        text,
                        TextStyle(
                          color: Theme.of(context).colorScheme.onInverseSurface,
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
      if (data.series.length > 1 || !data.series.first.path.isRoot)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: legend(seriesLabels(context, data), colors),
        ),
    ],
  );
}

/// One line per series. The X axis is a time axis when every category has
/// a period start, numeric when every value is a number, else categorical.
Widget lineChart(BuildContext context, ChartData source) {
  // an empty group has no place on a numeric or time axis, but is a
  // category like any other on a categorical one
  final trimmed = source.withoutEmpty();
  final axis = LineAxis.of(trimmed);
  final data = axis == LineAxis.categorical ? source : trimmed;
  final colors = seriesColors(context, data.series.length);
  double x(int i) => switch (axis) {
    LineAxis.time =>
      data.categories[i].periodStart!.millisecondsSinceEpoch / 86400000.0,
    LineAxis.numeric => data.categories[i].number!.toDouble(),
    LineAxis.categorical => i.toDouble(),
  };
  Widget bottom(double v, TitleMeta meta) {
    final text = switch (axis) {
      LineAxis.time => _date(
        DateTime.fromMillisecondsSinceEpoch(
          (v * 86400000).round(),
          isUtc: true,
        ),
      ),
      LineAxis.numeric => shortNumber(v),
      LineAxis.categorical => null,
    };
    if (text == null) return _categoryTitles(context, data)(v, meta);
    return _bottomTitle(text, meta);
  }

  return Column(
    children: [
      Expanded(
        child: Padding(
          padding: _rightMargin,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final range = _AxisRange([
                for (final s in data.series)
                  for (final v in s.values) ?v,
              ], ticks: _ticksFor(constraints.maxHeight));
              // a real axis is rounded to its ticks too; positions stay
              final xRange =
                  axis == LineAxis.categorical || data.categories.isEmpty
                  ? null
                  : _AxisRange(
                      [for (var i = 0; i < data.categories.length; i++) x(i)],
                      includeZero: false,
                      ticks: _ticksFor(
                        constraints.maxWidth,
                        // dates are wide
                        per: axis == LineAxis.time ? 160 : 90,
                      ),
                    );
              // half a slot of room at both ends of a categorical axis
              final minX = xRange?.min ?? -0.5;
              final maxX = xRange?.max ?? data.categories.length - 0.5;
              return LineChart(
                LineChartData(
                  minY: range.min,
                  maxY: range.max,
                  minX: minX,
                  maxX: maxX,
                  lineBarsData: [
                    for (var s = 0; s < data.series.length; s++)
                      LineChartBarData(
                        color: colors[s],
                        barWidth: 2,
                        dotData: FlDotData(show: data.categories.length <= 60),
                        spots: [
                          for (var i = 0; i < data.categories.length; i++)
                            if (data.series[s].values[i] case final v?)
                              FlSpot(x(i), v)
                            // a blank cell breaks the line on a categorical axis;
                            // on a real axis there is simply no point there
                            else if (axis == LineAxis.categorical)
                              FlSpot.nullSpot,
                        ],
                      ),
                  ],
                  titlesData: _titles(
                    bottom: bottom,
                    leftInterval: range.interval,
                    bottomInterval: xRange?.interval ?? 1,
                    bottomEnds: xRange == null,
                    bottomSize: xRange == null ? _bottomSize(data) : 28,
                  ),
                  gridData: _grid(range.interval),
                  borderData: FlBorderData(show: false),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (spots) => [
                        for (final spot in spots)
                          LineTooltipItem(
                            '${seriesLabels(context, data)[spot.barIndex]}: ${shortNumber(spot.y)}',
                            TextStyle(color: colors[spot.barIndex]),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(switch (axis) {
          LineAxis.time => 'time axis (periodStart)',
          LineAxis.numeric => 'numeric axis (value)',
          LineAxis.categorical => 'categorical axis (label)',
        }, style: Theme.of(context).textTheme.bodySmall),
      ),
      if (data.series.length > 1)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: legend(seriesLabels(context, data), colors),
        ),
    ],
  );
}

/// The first series as a pie; blank and non-positive values are left out.
Widget pieChart(BuildContext context, ChartData data) {
  final series = data.series.first;
  final slices = [
    for (var i = 0; i < data.categories.length; i++)
      if (series.values[i] case final v? when v > 0) (i, v),
  ];
  if (slices.isEmpty) {
    return const Center(child: Text('No positive values to draw.'));
  }
  final total = slices.fold(0.0, (a, s) => a + s.$2);
  final colors = seriesColors(context, slices.length);
  return Column(
    children: [
      Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) => PieChart(
            PieChartData(
              sectionsSpace: 1,
              centerSpaceRadius: 0,
              sections: [
                for (var k = 0; k < slices.length; k++)
                  PieChartSectionData(
                    value: slices[k].$2,
                    color: colors[k],
                    title: slices[k].$2 / total >= 0.04
                        ? '${(slices[k].$2 / total * 100).round()}%'
                        : '',
                    titleStyle: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                    ),
                    // fill the pane
                    radius: (constraints.biggest.shortestSide / 2 - 8).clamp(
                      20.0,
                      400.0,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: legend([
          for (final s in slices) categoryLabels(context, data)[s.$1],
        ], colors),
      ),
    ],
  );
}

/// One dot per point, coloured by series; a group's dot grows with its
/// fact count.
Widget scatterChart(BuildContext context, ScatterData data) {
  final colors = seriesColors(context, data.series.length);
  final spots = <ScatterSpot>[];
  final labels = <(double, double), String>{};
  for (var s = 0; s < data.series.length; s++) {
    for (final p in data.series[s].points) {
      final spot = ScatterSpot(
        p.x,
        p.y,
        dotPainter: FlDotCirclePainter(
          color: colors[s].withValues(alpha: p.row == null ? 0.85 : 0.6),
          radius: p.row == null ? 3 + math.log(p.factCount + 1) : 3,
        ),
      );
      spots.add(spot);
      final series = pathLabel(
        context,
        data.series[s].path ?? DimensionPath.root,
        data.series[s].label,
      );
      labels[(p.x, p.y)] = [
        if (p.label.isNotEmpty) p.label,
        if (series.isNotEmpty) series,
        '${data.xLabel}: ${shortNumber(p.x)}',
        '${data.yLabel}: ${shortNumber(p.y)}',
        if (p.row == null) '${p.factCount} facts',
      ].join('\n');
    }
  }
  if (spots.isEmpty) return const Center(child: Text('No points to draw.'));
  return Column(
    children: [
      Expanded(
        child: Padding(
          padding: _rightMargin,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final xRange = _AxisRange(
                [for (final s in spots) s.x],
                includeZero: false,
                ticks: _ticksFor(constraints.maxWidth, per: 90),
              );
              final yRange = _AxisRange(
                [for (final s in spots) s.y],
                includeZero: false,
                ticks: _ticksFor(constraints.maxHeight),
              );
              return ScatterChart(
                ScatterChartData(
                  minX: xRange.min,
                  maxX: xRange.max,
                  minY: yRange.min,
                  maxY: yRange.max,
                  scatterSpots: spots,
                  titlesData: _titles(
                    bottom: (v, meta) => _bottomTitle(shortNumber(v), meta),
                    leftInterval: yRange.interval,
                    bottomInterval: xRange.interval,
                    bottomEnds: false,
                  ),
                  gridData: _grid(
                    yRange.interval,
                    verticalInterval: xRange.interval,
                  ),
                  borderData: FlBorderData(show: false),
                  scatterTouchData: ScatterTouchData(
                    touchTooltipData: ScatterTouchTooltipData(
                      getTooltipItems: (spot) => ScatterTooltipItem(
                        labels[(spot.x, spot.y)] ?? '',
                        textStyle: TextStyle(
                          color: Theme.of(context).colorScheme.onInverseSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          '${data.xLabel} → · ${data.yLabel} ↑',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
      if (data.series.length > 1 || data.series.first.label.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: legend([
            for (final s in data.series)
              pathLabel(context, s.path ?? DimensionPath.root, s.label),
          ], colors),
        ),
    ],
  );
}
