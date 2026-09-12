import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tessera/tessera.dart';

const region = ColumnDimension('region');
const country = ColumnDimension('country');
const category = ColumnDimension('category');
const year = DatePartDimension('date', DatePart.year);
const qty = Measure('qty');
final sumQty = Aggregate.sum(qty);

const _rows = <List<Object?>>[
  ['Europe', 'Germany', 'A', '2024-01-05', 1],
  ['Europe', 'Germany', 'B', '2024-03-05', 2],
  ['Europe', 'Hungary', 'A', '2025-01-05', 3],
  ['Europe', null, 'A', '2025-02-05', 4],
  ['Asia', 'Japan', 'B', '2024-06-05', 5],
  ['Asia', 'Japan', null, '2025-06-05', 6],
  [null, 'Iceland', 'A', '2024-09-05', 7],
  [null, null, null, null, null],
];

Future<FactTable> facts() async {
  final source = ListDataSource(
    columns: ['region', 'country', 'category', 'date', 'qty'],
    rows: _rows,
    declaredSchema: Schema([
      const ColumnSpec(name: 'region', type: ColumnType.text),
      const ColumnSpec(name: 'country', type: ColumnType.text),
      const ColumnSpec(name: 'category', type: ColumnType.text),
      const ColumnSpec(name: 'date', type: ColumnType.date),
      const ColumnSpec(name: 'qty', type: ColumnType.integer),
    ]),
  );
  return (await loadFacts(source)).facts;
}

List<String> labels(AxisLayout a) => [
  for (final e in a.entries)
    e.isSummary
        ? 'Σ'
        : e.value == null
        ? '∅'
        : e.label,
];

DimensionPath p(List<DimensionValue> entries) => DimensionPath(entries);

void main() {
  late FactTable f;
  setUpAll(() async => f = await facts());

  group('AxisSort.keyPath', () {
    final byA = p([const DimensionValue(category, 'A')]);

    test('sorts rows by the aggregate in a specific column', () {
      final l = Cube(
        facts: f,
        spec: CubeSpec(
          rows: CubeAxis(
            dimensions: [
              AxisDimension(
                region,
                sort: AxisSort(
                  by: SortBy.aggregate,
                  aggregate: sumQty,
                  keyPath: byA,
                  direction: SortDirection.descending,
                ),
              ),
            ],
          ),
          columns: CubeAxis.of([category]),
          aggregates: [sumQty],
        ),
      ).layout;
      // column A: Europe 8, ∅ 7, Asia none (null sorts smallest)
      expect(labels(l.rows), ['Europe', '∅', 'Asia', 'Σ']);
    });

    test('falls back to the summary when the key path is not visible', () {
      final byA2024 = byA.child(const DimensionValue(year, 2024));
      final cube = Cube(
        facts: f,
        spec: CubeSpec(
          rows: CubeAxis(
            dimensions: [
              AxisDimension(
                region,
                sort: AxisSort(
                  by: SortBy.aggregate,
                  aggregate: sumQty,
                  keyPath: byA2024,
                  direction: SortDirection.descending,
                ),
              ),
            ],
          ),
          columns: CubeAxis.of([category, year]),
          aggregates: [sumQty],
        ),
      );
      // A is collapsed → by row totals: Asia 11, Europe 10, ∅ 7
      expect(labels(cube.layout.rows), ['Asia', 'Europe', '∅', 'Σ']);
      // expand A → A/2024: ∅ 7 (Iceland), Europe 1, Asia none
      final expanded = cube.toggleColumn(byA);
      expect(labels(expanded.layout.rows), ['∅', 'Europe', 'Asia', 'Σ']);
    });

    test('works for columns keyed by a row path too', () {
      final europe = p([const DimensionValue(region, 'Europe')]);
      final l = Cube(
        facts: f,
        spec: CubeSpec(
          rows: CubeAxis.of([region]),
          columns: CubeAxis(
            dimensions: [
              AxisDimension(
                category,
                sort: AxisSort(
                  by: SortBy.aggregate,
                  aggregate: sumQty,
                  keyPath: europe,
                  direction: SortDirection.descending,
                ),
              ),
            ],
          ),
          aggregates: [sumQty],
        ),
      ).layout;
      // Europe row: A 8, B 2, ∅ none
      expect(labels(l.columns), ['A', 'B', '∅', 'Σ']);
    });

    test('a key path on the wrong axis is treated as the summary', () {
      final l = Cube(
        facts: f,
        spec: CubeSpec(
          rows: CubeAxis(
            dimensions: [
              AxisDimension(
                region,
                sort: AxisSort(
                  by: SortBy.aggregate,
                  aggregate: sumQty,
                  keyPath: p([const DimensionValue(region, 'Asia')]),
                ),
              ),
            ],
          ),
          columns: CubeAxis.of([category]),
          aggregates: [sumQty],
        ),
      ).layout;
      expect(labels(l.rows), ['∅', 'Europe', 'Asia', 'Σ']); // 7, 10, 11
    });
  });

  group('HeaderEntry.childCount', () {
    test('counts the groups an expansion would add', () {
      final cube = Cube(
        facts: f,
        spec: CubeSpec(rows: CubeAxis.of([region, country])),
      );
      final l = cube.layout;
      expect(l.rows.entries.last.isSummary, isTrue);
      expect(l.rows.entries.last.childCount, 3); // ∅, Asia, Europe (expanded)
      final europe = l.rows.entries[2];
      expect(europe.label, 'Europe');
      expect(europe.childCount, 3); // ∅, Germany, Hungary
      expect(l.rows.entries[1].childCount, 1); // Asia → Japan
      expect(l.rows.entries[0].childCount, 2); // ∅ → ∅, Iceland

      final expanded = cube.toggleRow(europe.path).layout;
      expect(expanded.rows.entries[2].childCount, 3);
      expect(expanded.rows.entries[3].childCount, 0); // last level
      expect(expanded.rows.entries[3].isExpandable, isFalse);
    });

    test('respects the filter', () {
      final l = Cube(
        facts: f,
        spec: CubeSpec(
          rows: CubeAxis.of([region, country]),
          filter: ValueFilter(category, {'A'}),
        ),
      ).layout;
      expect(labels(l.rows), ['∅', 'Europe', 'Σ']);
      expect(l.rows.entries[1].childCount, 3); // Germany, Hungary, ∅
      expect(l.rows.entries[0].childCount, 1); // Iceland
    });

    test('collapsed root reports the first level', () {
      final l = Cube(
        facts: f,
        spec: CubeSpec(rows: CubeAxis.of([region])),
        rowExpansion: ExpansionState.collapsed(),
      ).layout;
      expect(l.rows.entries.single.childCount, 3);
      expect(
        Cube(facts: f, spec: CubeSpec()).layout.rows.entries.single.childCount,
        0,
      );
    });
  });

  group('AxisLayout.descendantCount', () {
    test('subtree sizes in outline order', () {
      final europe = p([const DimensionValue(region, 'Europe')]);
      final l = Cube(
        facts: f,
        spec: CubeSpec(rows: CubeAxis.of([region, country])),
      ).toggleRow(europe).layout;
      expect(labels(l.rows), [
        '∅',
        'Asia',
        'Europe',
        '∅',
        'Germany',
        'Hungary',
        'Σ',
      ]);
      expect(
        [for (var i = 0; i < l.rows.length; i++) l.rows.descendantCount(i)],
        [0, 0, 3, 0, 0, 0, 0],
      );
    });

    test('summary at the start spans everything', () {
      final l = Cube(
        facts: f,
        spec: CubeSpec(
          rows: CubeAxis.of([
            region,
            country,
          ], summaryPosition: SummaryPosition.start),
        ),
      ).expandRowsToDepth(2).layout;
      expect(l.rows.descendantCount(0), l.rows.length - 1);
      expect(l.rows.descendantCount(1), 2); // ∅ → ∅, Iceland
    });
  });

  test('isoWeek', () {
    expect(isoWeek(DateTime.utc(2024, 12, 30)), 1);
    expect(isoWeek(DateTime.utc(2021, 1, 3)), 53);
    expect(isoWeek(DateTime.utc(2025, 9, 12)), 37);
    expect(isoWeek(DateTime.utc(2026, 1, 1)), 1);
    expect(
      const DatePartDimension(
        'date',
        DatePart.week,
      ).valueOf(DateTime.utc(2021, 1, 3)),
      53,
    );
  });

  test('standardDimensions lists columns and date parts', () async {
    final file = File('example/assets/sales.csv');
    final facts = (await loadFacts(CsvDataSource.fromBytes(file.openRead)))
        .facts;
    final dims = standardDimensions(facts);
    final ids = dims.map((d) => d.id).toList();
    expect(ids.take(3), ['id', 'date', 'date.year']);
    expect(
      ids,
      containsAll([
        'date.quarter',
        'date.month',
        'date.week',
        'date.day',
        'date.weekday',
        'region',
        'total',
      ]),
    );
    expect(ids, isNot(contains('date.hour')));
    expect(dims.length, facts.columns.length + DatePart.values.length - 1);
    expect(dims.toSet().length, dims.length);
    // typed sources with dateTime get the hour part
    final dt = (await loadFacts(
      ListDataSource(
        columns: ['t'],
        rows: [
          [DateTime.utc(2025, 1, 1, 8)],
        ],
        declaredSchema: Schema([
          const ColumnSpec(name: 't', type: ColumnType.dateTime),
        ]),
      ),
    )).facts;
    expect(standardDimensions(dt).map((d) => d.id), contains('t.hour'));
  });
}
