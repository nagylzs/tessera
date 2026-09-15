import '../cube/aggregate.dart';
import '../cube/cube.dart';
import '../cube/cube_layout.dart';
import '../cube/cube_spec.dart';
import '../cube/dimension_path.dart';
import '../cube/filter.dart';
import '../facts/dimension.dart';
import '../facts/fact_table.dart';
import '../l10n/l10n_en.dart';
import '../l10n/tessera_strings.dart';
import 'chart_entries.dart';

/// One position on a chart's category axis: a group of the row axis (or
/// the column axis when transposed).
///
/// [value] is the group's raw dimension value, so a chart can place it on a
/// numeric or time axis: a [DateTime] (UTC) for a date column, an [int] for
/// integer columns and every date part (`month` 1..12, `quarter` 1..4,
/// `weekday` with Monday = 1, ISO `week`), a [double] for decimals, text or
/// [bool] otherwise. `null` for the empty group and the summary. [label] is
/// the same value formatted, or the localized "(empty)" / "Total".
final class ChartCategory {
  const ChartCategory({
    required this.path,
    required this.label,
    required this.value,
    required this.factCount,
  });

  /// The group's path on its axis; [DimensionPath.root] for the summary.
  final DimensionPath path;
  final String label;
  final Object? value;

  /// Facts in the group (after the cube's filter).
  final int factCount;

  bool get isSummary => path.isRoot;

  /// The "(empty)" group: facts without a value in the dimension.
  bool get isEmptyGroup => !isSummary && value == null;

  /// [value] when it is a number, else `null`.
  num? get number => value is num ? value as num : null;

  /// [value] when it is a date, else `null`.
  DateTime? get date => value is DateTime ? value as DateTime : null;

  /// The start of the period the path describes, for a time axis.
  ///
  /// A date column's value is returned as is. Date parts compose along the
  /// path — `[date.year, date.quarter]` at `2024 › Q2` gives 2024-04-01 —
  /// as long as they belong to one column and each part has what it needs:
  /// a year; a month for a day; a year for a week (the ISO week's Monday).
  /// `null` when the path has no usable date parts (a month without a year,
  /// a weekday, text …).
  DateTime? get periodStart {
    if (value is DateTime) return value as DateTime;
    int? year, quarter, month, week, day, hour;
    String? column;
    for (final e in path.entries) {
      final d = e.dimension;
      if (d is! DatePartDimension || e.value is! int) continue;
      if (column != null && d.sourceColumn != column) continue;
      column = d.sourceColumn;
      final v = e.value as int;
      switch (d.part) {
        case DatePart.year:
          year = v;
        case DatePart.quarter:
          quarter = v;
        case DatePart.month:
          month = v;
        case DatePart.week:
          week = v;
        case DatePart.day:
          day = v;
        case DatePart.hour:
          hour = v;
        case DatePart.weekday:
          break;
      }
    }
    if (year == null) return null;
    if (week != null && month == null && quarter == null) {
      // ISO 8601: week 1 contains January 4th.
      final jan4 = DateTime.utc(year, 1, 4);
      final monday = jan4.subtract(Duration(days: jan4.weekday - 1));
      return monday.add(Duration(days: (week - 1) * 7));
    }
    final m = month ?? (quarter == null ? 1 : quarter * 3 - 2);
    if (day != null && month == null) return DateTime.utc(year, m, 1);
    return DateTime.utc(year, m, day ?? 1, hour ?? 0);
  }

  @override
  String toString() => 'ChartCategory($label)';
}

/// One series of a chart: a group of the column axis (or the row axis when
/// transposed), with one value per [ChartData.categories] entry.
final class ChartSeries {
  const ChartSeries({
    required this.path,
    required this.label,
    required this.value,
    required this.factCount,
    required this.values,
  });

  /// The group's path on its axis; [DimensionPath.root] when the series is
  /// the summary (or the only series of a cube without column dimensions).
  final DimensionPath path;
  final String label;

  /// The group's raw dimension value; `null` for the empty group and the
  /// summary.
  final Object? value;

  /// Facts in the group (after the cube's filter).
  final int factCount;

  /// `values[i]` belongs to `categories[i]`; `null` where the cell is blank
  /// (no facts, or the aggregate has no result) — a gap, not a zero.
  final List<double?> values;

  @override
  String toString() => 'ChartSeries($label, ${values.length} values)';
}

/// Chart-ready series data — categories on one axis, one or more series of
/// values — computed from a [CubeLayout] or built from facts.
///
/// The type is format-neutral: it holds labels, raw values and doubles, and
/// leaves drawing to the application's chart library. The three ways to
/// obtain one all read a layout's cells, so a chart always agrees with the
/// table: [ChartData.fromLayout] takes the cube as displayed (categories
/// from the row entries, series from the column entries), [fromFacts]
/// builds a one- or two-dimensional cube for the purpose, and [fromCell]
/// drills into one cell's facts by another dimension.
final class ChartData {
  const ChartData({
    required this.aggregate,
    required this.aggregateLabel,
    required this.categories,
    required this.series,
  });

  /// What the values measure.
  final Aggregate aggregate;

  /// [aggregate]'s label, for the value axis.
  final String aggregateLabel;

  final List<ChartCategory> categories;
  final List<ChartSeries> series;

  /// Series data read from [layout]'s cells as they are.
  ///
  /// [rows] selects the categories among the row entries, [columns] the
  /// series among the column entries (both default to the visible leaves,
  /// see [ChartEntries]); [transpose] swaps the roles. [aggregate] must be
  /// one of the spec's (default: the first). A layout without column
  /// dimensions gives a single series labelled after the aggregate.
  factory ChartData.fromLayout(
    CubeLayout layout, {
    Aggregate? aggregate,
    ChartEntries rows = ChartEntries.leaves,
    ChartEntries columns = ChartEntries.leaves,
    bool transpose = false,
    TesseraStrings strings = const TesseraStringsEn(),
  }) {
    final a = aggregate ?? layout.spec.aggregates.first;
    if (!layout.spec.aggregates.contains(a)) {
      throw ArgumentError.value(a, 'aggregate', 'not in the spec');
    }
    final aggregateLabel = strings.aggregateLabel(a, layout.facts);
    final categoryEntries = transpose
        ? columns.select(layout.columns)
        : rows.select(layout.rows);
    final seriesEntries = transpose
        ? rows.select(layout.rows)
        : columns.select(layout.columns);
    final seriesAxis = transpose ? layout.spec.rows : layout.spec.columns;
    final categories = [
      for (final e in categoryEntries)
        ChartCategory(
          path: e.path,
          label: _label(e, strings),
          value: e.isSummary ? null : e.value,
          factCount: e.factCount,
        ),
    ];
    final series = [
      for (final s in seriesEntries)
        ChartSeries(
          path: s.path,
          // a cube without column dimensions has one series: the aggregate
          label: s.isSummary && seriesAxis.isEmpty
              ? aggregateLabel
              : _label(s, strings),
          value: s.isSummary ? null : s.value,
          factCount: s.factCount,
          values: [
            for (final c in categoryEntries)
              _valueOf(
                transpose
                    ? layout.cellFor(s.path, c.path)
                    : layout.cellFor(c.path, s.path),
                a,
              ),
          ],
        ),
    ];
    return ChartData(
      aggregate: a,
      aggregateLabel: aggregateLabel,
      categories: categories,
      series: series,
    );
  }

  /// [aggregate] of [facts] grouped by [category] (one category per
  /// distinct value, in [sort] order) and optionally by [series]; [filter]
  /// restricts the facts first.
  ///
  /// Builds a cube with [category] on the rows and [series] on the columns
  /// and reads it with [fromLayout], so the result is what a pivot with the
  /// same spec would show.
  factory ChartData.fromFacts(
    FactTable facts, {
    required Dimension category,
    Dimension? series,
    required Aggregate aggregate,
    FactFilter? filter,
    AxisSort? sort,
    AxisSort? seriesSort,
    TesseraStrings strings = const TesseraStringsEn(),
  }) {
    final cube = Cube(
      facts: facts,
      spec: CubeSpec(
        rows: CubeAxis(dimensions: [AxisDimension(category, sort: sort)]),
        columns: series == null
            ? const CubeAxis()
            : CubeAxis(dimensions: [AxisDimension(series, sort: seriesSort)]),
        aggregates: [aggregate],
        filter: filter,
      ),
    );
    return ChartData.fromLayout(cube.layout, strings: strings);
  }

  /// The facts behind [cell] (its coordinate and the cube's filter) broken
  /// down by [category] and optionally [series] — a drill-down. [aggregate]
  /// defaults to the first of [layout]'s spec but may be any aggregate.
  factory ChartData.fromCell(
    CubeLayout layout,
    CubeCell cell, {
    required Dimension category,
    Dimension? series,
    Aggregate? aggregate,
    AxisSort? sort,
    AxisSort? seriesSort,
    TesseraStrings strings = const TesseraStringsEn(),
  }) => ChartData.fromFacts(
    layout.facts,
    category: category,
    series: series,
    aggregate: aggregate ?? layout.spec.aggregates.first,
    filter: cellFilter(layout, cell),
    sort: sort,
    seriesSort: seriesSort,
    strings: strings,
  );

  /// The same data with the empty-group categories removed — for a numeric
  /// or time axis, where a `null` value has no place.
  ChartData withoutEmpty() {
    final keep = [
      for (var i = 0; i < categories.length; i++)
        if (!categories[i].isEmptyGroup) i,
    ];
    if (keep.length == categories.length) return this;
    return ChartData(
      aggregate: aggregate,
      aggregateLabel: aggregateLabel,
      categories: [for (final i in keep) categories[i]],
      series: [
        for (final s in series)
          ChartSeries(
            path: s.path,
            label: s.label,
            value: s.value,
            factCount: s.factCount,
            values: [for (final i in keep) s.values[i]],
          ),
      ],
    );
  }

  /// Categories and series swapped.
  ChartData transposed() => ChartData(
    aggregate: aggregate,
    aggregateLabel: aggregateLabel,
    categories: [
      for (final s in series)
        ChartCategory(
          path: s.path,
          label: s.label,
          value: s.value,
          factCount: s.factCount,
        ),
    ],
    series: [
      for (var i = 0; i < categories.length; i++)
        ChartSeries(
          path: categories[i].path,
          label: categories[i].label,
          value: categories[i].value,
          factCount: categories[i].factCount,
          values: [for (final s in series) s.values[i]],
        ),
    ],
  );

  @override
  String toString() =>
      'ChartData($aggregateLabel: ${categories.length} categories × '
      '${series.length} series)';
}

/// The filter selecting exactly the facts of [cell] in [layout]: the cube's
/// own filter and the cell's coordinate.
FactFilter? cellFilter(CubeLayout layout, CubeCell cell) {
  final own = layout.spec.filter;
  final at = cell.coordinate.toFilter();
  if (own == null) return at;
  if (at == null) return own;
  return AndFilter([own, at]);
}

String _label(HeaderEntry e, TesseraStrings strings) => e.isSummary
    ? strings.total
    : e.value == null
    ? strings.emptyGroup
    : strings.formatValue(e.dimension, e.value);

double? _valueOf(CubeCell? cell, Aggregate aggregate) {
  if (cell == null || cell.isEmpty) return null;
  final v = cell.aggregate(aggregate);
  return v is num ? v.toDouble() : null;
}
