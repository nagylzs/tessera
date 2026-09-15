import 'dart:io';

import 'package:test/test.dart';
import 'package:tessera/tessera.dart';

/// region, country, date, qty, price
const _rows = <List<Object?>>[
  ['Europe', 'Germany', '2024-01-05', 1, 10.0],
  ['Europe', 'Hungary', '2024-03-05', 2, 20.0],
  ['Europe', 'Germany', '2025-01-05', 4, null],
  ['Asia', 'Japan', '2024-06-05', 8, 40.0],
  ['Asia', 'Japan', '2025-06-05', 16, 50.0],
  [null, 'Iceland', '2024-02-01', 32, 60.0],
];

Future<FactTable> facts() async {
  final source = ListDataSource(
    columns: ['region', 'country', 'date', 'qty', 'price'],
    rows: _rows,
    declaredSchema: Schema([
      const ColumnSpec(name: 'region', type: ColumnType.text),
      const ColumnSpec(name: 'country', type: ColumnType.text),
      const ColumnSpec(name: 'date', type: ColumnType.date),
      const ColumnSpec(name: 'qty', type: ColumnType.integer),
      const ColumnSpec(name: 'price', type: ColumnType.number),
    ]),
  );
  return (await loadFacts(source)).facts;
}

const region = ColumnDimension('region');
const country = ColumnDimension('country');
const date = ColumnDimension('date');
const year = DatePartDimension('date', DatePart.year);
const quarter = DatePartDimension('date', DatePart.quarter);
const month = DatePartDimension('date', DatePart.month);
const week = DatePartDimension('date', DatePart.week);
const day = DatePartDimension('date', DatePart.day);
final sumQty = Aggregate.sum(const Measure('qty'));
final avgPrice = Aggregate.average(const Measure('price'));

DimensionPath p(List<DimensionValue> entries) => DimensionPath(entries);

void main() {
  late FactTable f;
  setUpAll(() async {
    f = await facts();
  });

  group('ChartEntries', () {
    late CubeLayout l;
    setUp(() {
      l = Cube(
        facts: f,
        spec: CubeSpec(
          rows: CubeAxis.of([region, country]),
          aggregates: [sumQty],
        ),
      ).toggleRow(p([const DimensionValue(region, 'Europe')])).layout;
    });

    test('leaves are the visible leaves, expanded parents excluded', () {
      final labels = [
        for (final e in ChartEntries.leaves.select(l.rows)) e.label,
      ];
      // (empty), Asia collapsed, Germany + Hungary under Europe
      expect(labels, ['', 'Asia', 'Germany', 'Hungary']);
    });

    test('level picks one depth', () {
      final labels = [
        for (final e in const ChartEntries.level(1).select(l.rows)) e.label,
      ];
      expect(labels, ['', 'Asia', 'Europe']);
      final deeper = [
        for (final e in const ChartEntries.level(2).select(l.rows)) e.label,
      ];
      expect(deeper, ['Germany', 'Hungary']);
    });

    test('all includes the summary', () {
      expect(ChartEntries.all.select(l.rows).last.isSummary, isTrue);
      expect(ChartEntries.all.select(l.rows).length, l.rows.length);
    });

    test('paths keeps the order and skips unknown paths', () {
      final selected = ChartEntries.paths([
        p([const DimensionValue(region, 'Asia')]),
        p([const DimensionValue(region, 'Mars')]),
        DimensionPath.root,
      ]).select(l.rows);
      expect([for (final e in selected) e.label], ['Asia', '']);
      expect(selected.last.isSummary, isTrue);
    });

    test('leaves of an axis without dimensions is the summary', () {
      final selected = ChartEntries.leaves.select(l.columns);
      expect(selected, hasLength(1));
      expect(selected.single.isSummary, isTrue);
    });
  });

  group('ChartData.fromLayout', () {
    test('rows become categories, columns series, cells values', () {
      final l = Cube(
        facts: f,
        spec: CubeSpec(
          rows: CubeAxis.of([region]),
          columns: CubeAxis.of([year]),
          aggregates: [sumQty, avgPrice],
        ),
      ).layout;
      final chart = ChartData.fromLayout(l);
      expect(chart.aggregate, sumQty);
      expect(chart.aggregateLabel, 'sum of qty');
      expect(
        [for (final c in chart.categories) c.label],
        ['(empty)', 'Asia', 'Europe'],
      );
      expect(
        [for (final c in chart.categories) c.value],
        [null, 'Asia', 'Europe'],
      );
      expect(chart.categories[0].isEmptyGroup, isTrue);
      expect(chart.categories[1].factCount, 2);
      expect([for (final s in chart.series) s.label], ['2024', '2025']);
      expect([for (final s in chart.series) s.value], [2024, 2025]);
      expect(chart.series[0].values, [32, 8, 3]);
      expect(chart.series[1].values, [null, 16, 4]); // no Iceland in 2025
      expect(chart.series[1].factCount, 2);
    });

    test('a named aggregate, and one not in the spec throws', () {
      final l = Cube(
        facts: f,
        spec: CubeSpec(rows: CubeAxis.of([region]), aggregates: [sumQty]),
      ).layout;
      expect(
        () => ChartData.fromLayout(l, aggregate: avgPrice),
        throwsArgumentError,
      );
    });

    test('no column dimensions: one series named after the aggregate', () {
      final l = Cube(
        facts: f,
        spec: CubeSpec(rows: CubeAxis.of([country]), aggregates: [avgPrice]),
      ).layout;
      final chart = ChartData.fromLayout(l);
      expect(chart.series, hasLength(1));
      expect(chart.series.single.label, 'avg of price');
      expect(chart.series.single.path, DimensionPath.root);
      expect(
        [for (final c in chart.categories) c.label],
        ['Germany', 'Hungary', 'Iceland', 'Japan'],
      );
      expect(chart.series.single.values, [10, 20, 60, 45]);
    });

    test('all entries mirror the table, summary labelled Total', () {
      final l = Cube(
        facts: f,
        spec: CubeSpec(
          rows: CubeAxis.of([region]),
          columns: CubeAxis.of([year]),
          aggregates: [sumQty],
        ),
      ).layout;
      final chart = ChartData.fromLayout(
        l,
        rows: ChartEntries.all,
        columns: ChartEntries.all,
      );
      expect(chart.categories.last.label, 'Total');
      expect(chart.categories.last.isSummary, isTrue);
      expect(chart.series.last.label, 'Total');
      expect(chart.series.last.values, [32, 24, 7, 63]);
    });

    test('transpose swaps the axes, as does transposed()', () {
      final l = Cube(
        facts: f,
        spec: CubeSpec(
          rows: CubeAxis.of([region]),
          columns: CubeAxis.of([year]),
          aggregates: [sumQty],
        ),
      ).layout;
      final plain = ChartData.fromLayout(l);
      final t = ChartData.fromLayout(l, transpose: true);
      expect([for (final c in t.categories) c.value], [2024, 2025]);
      expect(
        [for (final s in t.series) s.label],
        ['(empty)', 'Asia', 'Europe'],
      );
      expect(t.series[1].values, [8, 16]);
      final back = t.transposed();
      expect(
        [for (final c in back.categories) c.label],
        [for (final c in plain.categories) c.label],
      );
      expect(
        [for (final s in back.series) s.values],
        [for (final s in plain.series) s.values],
      );
      expect(back.categories[1].factCount, plain.categories[1].factCount);
    });

    test('expanded parents are skipped by default', () {
      final l = Cube(
        facts: f,
        spec: CubeSpec(
          rows: CubeAxis.of([region, country]),
          aggregates: [sumQty],
        ),
      ).toggleRow(p([const DimensionValue(region, 'Europe')])).layout;
      final chart = ChartData.fromLayout(l);
      expect(
        [for (final c in chart.categories) c.label],
        ['(empty)', 'Asia', 'Germany', 'Hungary'],
      );
      // every fact once: 32 + 24 + 5 + 2 = 63
      expect(chart.series.single.values.fold(0.0, (a, b) => a + b!), 63);
    });

    test('localized labels', () {
      final l = Cube(
        facts: f,
        spec: CubeSpec(rows: CubeAxis.of([month]), aggregates: [sumQty]),
      ).layout;
      final chart = ChartData.fromLayout(
        l,
        strings: TesseraStrings.forLanguage('hu')!,
      );
      expect(chart.categories.first.label, 'január');
      expect(chart.categories.first.value, 1);
      expect(chart.aggregateLabel, 'qty összege');
    });

    test('layout-relative aggregates work like in the table', () {
      final pct = PercentOfTotalAggregate(sumQty, TotalOf.column);
      final l = Cube(
        facts: f,
        spec: CubeSpec(rows: CubeAxis.of([region]), aggregates: [pct]),
      ).layout;
      final chart = ChartData.fromLayout(l);
      final values = chart.series.single.values;
      expect(values.fold(0.0, (a, b) => a + b!), closeTo(100, 1e-9));
    });
  });

  group('ChartCategory values', () {
    test('typed values: date, number, date parts', () {
      final byDate = ChartData.fromFacts(f, category: date, aggregate: sumQty);
      expect(byDate.categories.first.date, DateTime.utc(2024, 1, 5));
      expect(byDate.categories.first.periodStart, DateTime.utc(2024, 1, 5));
      expect(byDate.categories.first.number, isNull);
      expect(byDate.categories.first.label, startsWith('2024-01-05'));

      const qtyDim = ColumnDimension('qty');
      final byQty = ChartData.fromFacts(f, category: qtyDim, aggregate: sumQty);
      expect(
        [for (final c in byQty.categories) c.number],
        [1, 2, 4, 8, 16, 32],
      );
      expect(byQty.categories.first.value, isA<int>());
      expect(byQty.categories.first.date, isNull);

      final byYear = ChartData.fromFacts(f, category: year, aggregate: sumQty);
      expect(byYear.categories.first.value, 2024);
      expect(byYear.categories.first.periodStart, DateTime.utc(2024));
    });

    test('periodStart composes nested date parts', () {
      DateTime? startOf(List<Dimension> dims, List<int> values) {
        return ChartCategory(
          path: p([
            for (var i = 0; i < dims.length; i++)
              DimensionValue(dims[i], values[i]),
          ]),
          label: '',
          value: values.last,
          factCount: 0,
        ).periodStart;
      }

      expect(startOf([year, quarter], [2024, 2]), DateTime.utc(2024, 4));
      expect(startOf([year, month], [2024, 11]), DateTime.utc(2024, 11));
      expect(
        startOf([year, month, day], [2024, 2, 29]),
        DateTime.utc(2024, 2, 29),
      );
      expect(startOf([year, week], [2024, 1]), DateTime.utc(2024, 1, 1));
      expect(startOf([year, week], [2021, 1]), DateTime.utc(2021, 1, 4));
      expect(startOf([year, week], [2020, 53]), DateTime.utc(2020, 12, 28));
    });

    test('periodStart is null without a year or for a weekday', () {
      ChartCategory of(Dimension d, Object? v) => ChartCategory(
        path: p([DimensionValue(d, v)]),
        label: '',
        value: v,
        factCount: 0,
      );
      expect(of(month, 3).periodStart, isNull);
      expect(
        of(const DatePartDimension('date', DatePart.weekday), 1).periodStart,
        isNull,
      );
      expect(of(region, 'Asia').periodStart, isNull);
      expect(of(region, null).periodStart, isNull);
    });
  });

  group('ChartData.fromFacts / fromCell', () {
    test('fromFacts groups, sorts and filters', () {
      final chart = ChartData.fromFacts(
        f,
        category: country,
        series: year,
        aggregate: sumQty,
        filter: ValueFilter(region, ['Europe']),
        sort: AxisSort(direction: SortDirection.descending),
      );
      expect(
        [for (final c in chart.categories) c.label],
        ['Hungary', 'Germany'],
      );
      expect([for (final s in chart.series) s.label], ['2024', '2025']);
      expect(chart.series[0].values, [2, 1]);
      expect(chart.series[1].values, [null, 4]);
    });

    test('fromCell drills into one cell', () {
      final l = Cube(
        facts: f,
        spec: CubeSpec(
          rows: CubeAxis.of([region]),
          columns: CubeAxis.of([year]),
          aggregates: [sumQty],
          filter: ValueFilter(country, ['Germany', 'Hungary', 'Japan']),
        ),
      ).layout;
      final cell = l.cellFor(
        p([const DimensionValue(region, 'Europe')]),
        p([const DimensionValue(year, 2024)]),
      )!;
      final chart = ChartData.fromCell(l, cell, category: country);
      expect(
        [for (final c in chart.categories) c.label],
        ['Germany', 'Hungary'],
      );
      expect(chart.series.single.values, [1, 2]);
      // the summary cell drills into everything the cube's filter allows
      final all = ChartData.fromCell(
        l,
        l.cellFor(DimensionPath.root, DimensionPath.root)!,
        category: country,
      );
      expect(all.categories, hasLength(3)); // Iceland filtered out
    });

    test('cellFilter and Coordinate.toFilter', () {
      final l = Cube(
        facts: f,
        spec: CubeSpec(
          rows: CubeAxis.of([region]),
          columns: CubeAxis.of([year]),
          aggregates: [sumQty],
        ),
      ).layout;
      final root = l.cellFor(DimensionPath.root, DimensionPath.root)!;
      expect(root.coordinate.toFilter(), isNull);
      expect(cellFilter(l, root), isNull);
      final one = l.cellFor(
        p([const DimensionValue(region, null)]),
        DimensionPath.root,
      )!;
      final filter = one.coordinate.toFilter()!;
      expect(filter, isA<ValueFilter>());
      expect(filter.matches(f, 5), isTrue); // Iceland, no region
      expect(filter.matches(f, 0), isFalse);
      final two = l.cellFor(
        p([const DimensionValue(region, 'Asia')]),
        p([const DimensionValue(year, 2025)]),
      )!;
      expect(two.coordinate.toFilter(), isA<AndFilter>());
      expect(
        [
          for (var r = 0; r < f.rowCount; r++)
            two.coordinate.toFilter()!.matches(f, r),
        ],
        [false, false, false, false, true, false],
      );
    });

    test('withoutEmpty drops the empty group in every series', () {
      final chart = ChartData.fromFacts(
        f,
        category: region,
        series: year,
        aggregate: sumQty,
      );
      expect(chart.categories.first.isEmptyGroup, isTrue);
      final clean = chart.withoutEmpty();
      expect([for (final c in clean.categories) c.label], ['Asia', 'Europe']);
      expect(clean.series[0].values, [8, 3]);
      expect(clean.series[1].values, [16, 4]);
      expect(identical(clean.withoutEmpty(), clean), isTrue);
    });
  });

  group('ScatterData', () {
    test('fromLayout: one point per row entry, a series per column entry', () {
      final l = Cube(
        facts: f,
        spec: CubeSpec(
          rows: CubeAxis.of([country]),
          columns: CubeAxis.of([year]),
          aggregates: [sumQty, avgPrice],
        ),
      ).layout;
      final s = ScatterData.fromLayout(l, x: sumQty, y: avgPrice);
      expect(s.xLabel, 'sum of qty');
      expect(s.yLabel, 'avg of price');
      expect(s.xAggregate, sumQty);
      expect([for (final e in s.series) e.label], ['2024', '2025']);
      final y2024 = s.series[0].points;
      expect(
        [for (final pt in y2024) pt.label],
        ['Germany', 'Hungary', 'Iceland', 'Japan'],
      );
      expect(y2024[0].x, 1);
      expect(y2024[0].y, 10);
      expect(y2024[0].factCount, 1); // Germany × 2024
      expect(s.series[0].points[3].factCount, 1); // Japan × 2024
      expect(y2024[0].path, p([const DimensionValue(country, 'Germany')]));
      // 2025: Germany has qty but no price → no point; Japan only
      expect([for (final pt in s.series[1].points) pt.label], ['Japan']);
      expect(s.points, hasLength(5));
    });

    test('fromFacts and fromCell, single unnamed series', () {
      final s = ScatterData.fromFacts(
        f,
        points: country,
        x: sumQty,
        y: avgPrice,
      );
      expect(s.series, hasLength(1));
      expect(s.series.single.label, '');
      expect(s.series.single.path, DimensionPath.root);
      expect(s.points, hasLength(4));

      final l = Cube(
        facts: f,
        spec: CubeSpec(rows: CubeAxis.of([region]), aggregates: [sumQty]),
      ).layout;
      final cell = l.cellFor(
        p([const DimensionValue(region, 'Europe')]),
        DimensionPath.root,
      )!;
      final drill = ScatterData.fromCell(
        l,
        cell,
        points: country,
        series: year,
        x: sumQty,
        y: avgPrice,
      );
      expect([for (final e in drill.series) e.label], ['2024', '2025']);
      expect(
        [for (final pt in drill.series[0].points) pt.label],
        ['Germany', 'Hungary'],
      );
      expect(drill.series[1].points, isEmpty); // Germany 2025 has no price
    });

    test('ofFacts: one point per fact, series by dimension', () {
      final s = ScatterData.ofFacts(
        f,
        x: const Measure('qty'),
        y: const Measure('price'),
        series: region,
        pointLabel: country,
      );
      expect(s.xMeasure, const Measure('qty'));
      expect(s.xLabel, 'qty');
      expect(
        [for (final e in s.series) e.label],
        ['(empty)', 'Asia', 'Europe'],
      );
      expect([for (final e in s.series) e.path], [null, null, null]);
      expect(s.series[0].points.single.label, 'Iceland');
      expect(s.series[0].points.single.row, 5);
      expect(s.series[2].points, hasLength(2)); // row 2 lacks a price
      expect(s.series[2].points[1].x, 2);
      expect(s.series[2].points[1].y, 20);
      expect(s.points, hasLength(5));
    });

    test('ofFacts with rows, filter and limit', () {
      final l = Cube(
        facts: f,
        spec: CubeSpec(rows: CubeAxis.of([region]), aggregates: [sumQty]),
      ).layout;
      final asia = l.cellFor(
        p([const DimensionValue(region, 'Asia')]),
        DimensionPath.root,
      )!;
      final s = ScatterData.ofFacts(
        f,
        x: const Measure('qty'),
        y: const Measure('price'),
        rows: asia.factRows,
      );
      expect(s.series.single.label, '');
      expect([for (final pt in s.points) pt.row], [3, 4]);
      expect(s.series.single.points.first.label, '');

      final limited = ScatterData.ofFacts(
        f,
        x: const Measure('qty'),
        y: const Measure('price'),
        filter: ExpressionFilter('price > 10'),
        limit: 2,
      );
      expect([for (final pt in limited.points) pt.row], [1, 3]);
    });
  });

  group('sales.csv', () {
    late FactTable sales;
    setUpAll(() async {
      final bytes = File('test/data/sales.csv').readAsBytesSync();
      sales = (await loadFacts(CsvDataSource.fromData(bytes))).facts;
    });

    test('a chart from facts equals the same pivot read cell by cell', () {
      const cat = ColumnDimension('category');
      const yr = DatePartDimension('date', DatePart.year);
      final total = Aggregate.sum(const Measure('total'));
      final chart = ChartData.fromFacts(
        sales,
        category: cat,
        series: yr,
        aggregate: total,
      );
      final l = Cube(
        facts: sales,
        spec: CubeSpec(
          rows: CubeAxis.of([cat]),
          columns: CubeAxis.of([yr]),
          aggregates: [total],
        ),
      ).layout;
      expect(chart.categories.length, l.rows.length - 1);
      expect(chart.series.length, l.columns.length - 1);
      for (var i = 0; i < chart.categories.length; i++) {
        for (var j = 0; j < chart.series.length; j++) {
          final cell = l.cellFor(
            chart.categories[i].path,
            chart.series[j].path,
          );
          expect(chart.series[j].values[i], cell?.aggregate(total));
        }
      }
      // the sum over the leaf categories is the grand total
      final grand = l
          .cellFor(DimensionPath.root, DimensionPath.root)!
          .aggregate(total)!;
      var sum = 0.0;
      for (final s in chart.series) {
        for (final v in s.values) {
          sum += v ?? 0;
        }
      }
      expect(sum, closeTo(grand, 1e-6));
    });

    test('a monthly time series has typed periods in order', () {
      const ym = [
        DatePartDimension('date', DatePart.year),
        DatePartDimension('date', DatePart.month),
      ];
      final l = Cube(
        facts: sales,
        spec: CubeSpec(rows: CubeAxis.of(ym), aggregates: [Aggregate.count]),
      ).expandRowsToDepth(2).layout;
      final chart = ChartData.fromLayout(l);
      final periods = [for (final c in chart.categories) c.periodStart!];
      for (var i = 1; i < periods.length; i++) {
        expect(periods[i].isAfter(periods[i - 1]), isTrue);
      }
      expect(periods.first.day, 1);
      expect(chart.categories.every((c) => c.path.length == 2), isTrue);
      expect(
        chart.series.single.values.fold(0.0, (a, b) => a + b!),
        sales.rowCount,
      );
    });

    test('per-fact scatter of the sales table', () {
      final s = ScatterData.ofFacts(
        sales,
        x: const Measure('quantity'),
        y: const Measure('unit_price'),
        series: const ColumnDimension('region'),
      );
      final withBoth = [
        for (var r = 0; r < sales.rowCount; r++)
          if (sales.valueAt(r, 'quantity') != null &&
              sales.valueAt(r, 'unit_price') != null)
            r,
      ];
      expect(s.points.length, withBoth.length);
      expect(
        s.series.length,
        sales.distinctValues(const ColumnDimension('region')).length,
      );
    });
  });
}
