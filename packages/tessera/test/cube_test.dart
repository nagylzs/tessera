import 'dart:io';

import 'package:test/test.dart';
import 'package:tessera/tessera.dart';

const region = ColumnDimension('region');
const country = ColumnDimension('country');
const category = ColumnDimension('category');
const year = DatePartDimension('date', DatePart.year);
const qty = Measure('qty');
const price = Measure('price');
final sumQty = Aggregate.sum(qty);

/// region, country, category, date, qty, price
const _rows = <List<Object?>>[
  ['Europe', 'Germany', 'A', '2024-01-05', 1, 10.0],
  ['Europe', 'Germany', 'B', '2024-03-05', 2, 20.0],
  ['Europe', 'Hungary', 'A', '2025-01-05', 3, 30.0],
  ['Europe', null, 'A', '2025-02-05', 4, null],
  ['Asia', 'Japan', 'B', '2024-06-05', 5, 50.0],
  ['Asia', 'Japan', null, '2025-06-05', 6, 60.0],
  [null, 'Iceland', 'A', '2024-09-05', 7, 70.0],
  [null, null, null, null, null, 80.0],
];

Future<FactTable> facts() async {
  final source = ListDataSource(
    columns: ['region', 'country', 'category', 'date', 'qty', 'price'],
    rows: _rows,
    declaredSchema: Schema([
      const ColumnSpec(name: 'region', type: ColumnType.text),
      const ColumnSpec(name: 'country', type: ColumnType.text),
      const ColumnSpec(name: 'category', type: ColumnType.text),
      const ColumnSpec(name: 'date', type: ColumnType.date),
      const ColumnSpec(name: 'qty', type: ColumnType.integer),
      const ColumnSpec(name: 'price', type: ColumnType.number),
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

List<List<Object?>> grid(CubeLayout l, Aggregate a) => [
  for (var i = 0; i < l.rows.length; i++)
    [
      for (var j = 0; j < l.columns.length; j++)
        l.cellAt(i, j).aggregate<Object?>(a),
    ],
];

DimensionPath p(List<DimensionValue> entries) => DimensionPath(entries);

void main() {
  late FactTable f;
  setUpAll(() async => f = await facts());

  group('Cube layout', () {
    test('first level visible, summary last, cells summed', () {
      final cube = Cube(
        facts: f,
        spec: CubeSpec(
          rows: CubeAxis.of([region, country]),
          columns: CubeAxis.of([category]),
          aggregates: [sumQty, Aggregate.count],
        ),
      );
      final l = cube.layout;
      expect(labels(l.rows), ['∅', 'Asia', 'Europe', 'Σ']);
      expect(labels(l.columns), ['∅', 'A', 'B', 'Σ']);
      expect(grid(l, sumQty), [
        [null, 7, null, 7], // no region: Iceland A=7, all-null row has no qty
        [6, null, 5, 11],
        [null, 8, 2, 10],
        [6, 15, 7, 28],
      ]);
      expect(grid(l, Aggregate.count), [
        [1, 1, 0, 2],
        [1, 0, 1, 2],
        [0, 3, 1, 4],
        [2, 4, 2, 8],
      ]);
      final empty = l.cellAt(0, 2);
      expect(empty.isEmpty, isTrue);
      expect(empty.factCount, 0);
      expect(empty.factRows, isEmpty);
      expect(empty.aggregate(Aggregate.count), 0);
      expect(l.cellAt(3, 3).factRows, [0, 1, 2, 3, 4, 5, 6, 7]);
      expect(l.cellAt(2, 1).factRows, [0, 2, 3]);
    });

    test('header entries describe the group', () {
      final l = Cube(
        facts: f,
        spec: CubeSpec(rows: CubeAxis.of([region, country])),
      ).layout;
      final europe = l.rows.entries[2];
      expect(europe.path, p([const DimensionValue(region, 'Europe')]));
      expect(europe.depth, 1);
      expect(europe.dimension, region);
      expect(europe.value, 'Europe');
      expect(europe.label, 'Europe');
      expect(europe.isExpandable, isTrue);
      expect(europe.isExpanded, isFalse);
      expect(europe.factCount, 4);
      final summary = l.rows.entries.last;
      expect(summary.isSummary, isTrue);
      expect(summary.path, DimensionPath.root);
      expect(summary.isExpandable, isTrue);
      expect(summary.isExpanded, isTrue);
      expect(summary.factCount, 8);
      expect(summary.label, '');
      expect(summary.dimension, isNull);
      expect(l.rows.indexOf(europe.path), 2);
      expect(l.rows.indexOf(p([const DimensionValue(region, 'Mars')])), -1);
    });

    test('expanding a group inserts its children after it', () {
      final europe = p([const DimensionValue(region, 'Europe')]);
      final cube = Cube(
        facts: f,
        spec: CubeSpec(
          rows: CubeAxis.of([region, country]),
          aggregates: [sumQty],
        ),
      ).toggleRow(europe);
      final l = cube.layout;
      expect(labels(l.rows), [
        '∅',
        'Asia',
        'Europe',
        '∅',
        'Germany',
        'Hungary',
        'Σ',
      ]);
      expect(l.rows.entries[2].isExpanded, isTrue);
      expect(l.rows.entries[3].depth, 2);
      expect(l.rows.entries[3].isExpandable, isFalse);
      expect(
        l.rows.entries[3].path,
        europe.child(const DimensionValue(country, null)),
      );
      // parent equals the merge of its children
      expect(grid(l, sumQty).map((r) => r.single), [7, 11, 10, 4, 3, 3, 28]);
      // toggling back restores the layout
      expect(labels(cube.toggleRow(europe).layout.rows), [
        '∅',
        'Asia',
        'Europe',
        'Σ',
      ]);
    });

    test('country without region is under the empty region', () {
      final noRegion = p([const DimensionValue(region, null)]);
      final l = Cube(
        facts: f,
        spec: CubeSpec(rows: CubeAxis.of([region, country])),
      ).toggleRow(noRegion).layout;
      expect(labels(l.rows), ['∅', '∅', 'Iceland', 'Asia', 'Europe', 'Σ']);
      expect(
        l
            .cellFor(
              noRegion.child(const DimensionValue(country, 'Iceland')),
              DimensionPath.root,
            )!
            .factCount,
        1,
      );
    });

    test('collapsing the root leaves only the summary', () {
      final cube = Cube(
        facts: f,
        spec: CubeSpec(rows: CubeAxis.of([region]), aggregates: [sumQty]),
        rowExpansion: ExpansionState.collapsed(),
      );
      expect(labels(cube.layout.rows), ['Σ']);
      expect(cube.layout.cellAt(0, 0).aggregate(sumQty), 28);
      expect(cube.layout.rows.entries.single.isExpanded, isFalse);
    });

    test('stale or foreign expansion paths are ignored', () {
      final cube = Cube(
        facts: f,
        spec: CubeSpec(rows: CubeAxis.of([region, country])),
        rowExpansion: ExpansionState.of([
          p([const DimensionValue(region, 'Mars')]),
          p([const DimensionValue(category, 'A')]),
          p([
            const DimensionValue(region, 'Asia'),
            const DimensionValue(country, 'Japan'),
          ]),
        ]),
      );
      expect(labels(cube.layout.rows), ['∅', 'Asia', 'Japan', 'Europe', 'Σ']);
    });

    test('empty axes give a single summary', () {
      final l = Cube(
        facts: f,
        spec: CubeSpec(aggregates: [sumQty]),
      ).layout;
      expect(l.rows.length, 1);
      expect(l.columns.length, 1);
      expect(l.rows.entries.single.isExpandable, isFalse);
      expect(l.cellAt(0, 0).aggregate(sumQty), 28);
      expect(l.cellAt(0, 0).coordinate.isEmpty, isTrue);
    });

    test('summary position start and hidden', () {
      final start = Cube(
        facts: f,
        spec: CubeSpec(
          rows: CubeAxis.of([region], summaryPosition: SummaryPosition.start),
        ),
      ).layout;
      expect(labels(start.rows), ['Σ', '∅', 'Asia', 'Europe']);
      final hidden = Cube(
        facts: f,
        spec: CubeSpec(
          rows: CubeAxis.of([region], summaryPosition: SummaryPosition.hidden),
        ),
      ).layout;
      expect(labels(hidden.rows), ['∅', 'Asia', 'Europe']);
      expect(hidden.cellFor(DimensionPath.root, DimensionPath.root), isNull);
    });

    test('sorting by value: direction and null position', () {
      final l = Cube(
        facts: f,
        spec: CubeSpec(
          rows: const CubeAxis(
            dimensions: [
              AxisDimension(
                region,
                sort: AxisSort(
                  direction: SortDirection.descending,
                  nulls: NullPosition.last,
                ),
              ),
            ],
          ),
        ),
      ).layout;
      expect(labels(l.rows), ['Europe', 'Asia', '∅', 'Σ']);
    });

    test('sorting by aggregate', () {
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
                  direction: SortDirection.descending,
                ),
              ),
            ],
          ),
          columns: CubeAxis(
            dimensions: [
              AxisDimension(
                category,
                sort: AxisSort(by: SortBy.aggregate, aggregate: sumQty),
              ),
            ],
          ),
          aggregates: [sumQty],
        ),
      ).layout;
      expect(labels(l.rows), ['Asia', 'Europe', '∅', 'Σ']); // 11, 10, 7
      expect(labels(l.columns), ['∅', 'B', 'A', 'Σ']); // 6, 7, 15
    });

    test('a level without its own sort inherits the level above', () {
      final byQtyDesc = AxisSort(
        by: SortBy.aggregate,
        aggregate: sumQty,
        direction: SortDirection.descending,
      );
      Cube cube(AxisSort? countrySort) => Cube(
        facts: f,
        spec: CubeSpec(
          rows: CubeAxis(
            dimensions: [
              AxisDimension(region, sort: byQtyDesc),
              AxisDimension(country, sort: countrySort),
            ],
          ),
          aggregates: [sumQty],
        ),
      ).expandRowsToDepth(2);
      final axis = cube(null).spec.rows;
      expect(axis.sortAt(0), same(byQtyDesc));
      expect(axis.sortAt(1), same(byQtyDesc));
      expect(
        CubeAxis.of([region, country]).sortAt(1).direction,
        SortDirection.ascending,
      );
      // Europe: ∅ 4, Germany 3, Hungary 3 → by qty desc, ties by value asc
      expect(labels(cube(null).layout.rows), [
        'Asia',
        'Japan',
        'Europe',
        '∅',
        'Germany',
        'Hungary',
        '∅',
        'Iceland',
        '∅',
        'Σ',
      ]);
      // an explicit value sort on the second level overrides it
      expect(labels(cube(const AxisSort()).layout.rows), [
        'Asia',
        'Japan',
        'Europe',
        '∅',
        'Germany',
        'Hungary',
        '∅',
        '∅',
        'Iceland',
        'Σ',
      ]);
    });

    test('sorting by an aggregate the cube lacks is an error', () {
      final cube = Cube(
        facts: f,
        spec: CubeSpec(
          rows: CubeAxis(
            dimensions: [
              AxisDimension(
                region,
                sort: AxisSort(by: SortBy.aggregate, aggregate: sumQty),
              ),
            ],
          ),
          aggregates: const [Aggregate.count],
        ),
      );
      expect(() => cube.layout, throwsArgumentError);
    });

    test('filter restricts the facts', () {
      final l = Cube(
        facts: f,
        spec: CubeSpec(
          rows: CubeAxis.of([region]),
          aggregates: [sumQty, Aggregate.count],
          filter: ValueFilter(category, {'A'}),
        ),
      ).layout;
      expect(labels(l.rows), ['∅', 'Europe', 'Σ']);
      expect(grid(l, sumQty).map((r) => r.single), [7, 8, 15]);
      expect(l.cellAt(2, 0).factRows, [0, 2, 3, 6]);
    });

    test('date part dimensions on the column axis', () {
      final l = Cube(
        facts: f,
        spec: CubeSpec(
          rows: CubeAxis.of([region]),
          columns: CubeAxis.of([year]),
          aggregates: [sumQty],
        ),
      ).layout;
      expect(labels(l.columns), ['∅', '2024', '2025', 'Σ']);
      expect(grid(l, sumQty), [
        [null, 7, null, 7],
        [null, 5, 6, 11],
        [null, 3, 7, 10],
        [null, 15, 13, 28],
      ]);
    });

    test('cell coordinate and other aggregates', () {
      final l = Cube(
        facts: f,
        spec: CubeSpec(
          rows: CubeAxis.of([region]),
          columns: CubeAxis.of([category]),
          aggregates: [
            Aggregate.average(price),
            Aggregate.min(price),
            Aggregate.max(price),
            Aggregate.countNonNull(price),
            Aggregate.distinctCount(country),
          ],
        ),
      ).layout;
      final europeA = l.cellFor(
        p([const DimensionValue(region, 'Europe')]),
        p([const DimensionValue(category, 'A')]),
      )!;
      expect(europeA.coordinate, Coordinate({region: 'Europe', category: 'A'}));
      expect(europeA.factCount, 3);
      expect(europeA.aggregate(Aggregate.average(price)), 20.0); // (10+30)/2
      expect(europeA.aggregate(Aggregate.min(price)), 10.0);
      expect(europeA.aggregate(Aggregate.max(price)), 30.0);
      expect(europeA.aggregate(Aggregate.countNonNull(price)), 2);
      expect(europeA.aggregate(Aggregate.distinctCount(country)), 2);
      expect(europeA.aggregates.length, 5);
      final total = l.cellFor(DimensionPath.root, DimensionPath.root)!;
      expect(total.aggregate(Aggregate.distinctCount(country)), 4);
      expect(total.aggregate(Aggregate.average(price)), closeTo(320 / 7, 1e-9));
      expect(() => europeA.aggregate(sumQty), throwsArgumentError);
    });

    test('expandRowsToDepth', () {
      final cube = Cube(
        facts: f,
        spec: CubeSpec(rows: CubeAxis.of([region, country])),
      );
      expect(labels(cube.expandRowsToDepth(0).layout.rows), ['Σ']);
      expect(labels(cube.expandRowsToDepth(1).layout.rows), [
        '∅',
        'Asia',
        'Europe',
        'Σ',
      ]);
      expect(labels(cube.expandRowsToDepth(2).layout.rows), [
        '∅',
        '∅',
        'Iceland',
        'Asia',
        'Japan',
        'Europe',
        '∅',
        'Germany',
        'Hungary',
        'Σ',
      ]);
      expect(
        cube.expandRowsToDepth(2).rowExpansion,
        cube.expandRowsToDepth(9).rowExpansion,
      );
    });

    test('expandRowLevel opens a whole level and keeps deeper state', () {
      final europe = p([const DimensionValue(region, 'Europe')]);
      final germany = europe.child(const DimensionValue(country, 'Germany'));
      final cube = Cube(
        facts: f,
        spec: CubeSpec(rows: CubeAxis.of([region, country, category])),
      );
      // from the initial state: same as depth 2
      expect(
        cube.expandRowLevel(0).rowExpansion,
        cube.expandRowsToDepth(2).rowExpansion,
      );
      // level 1 opens the countries of every region as well
      expect(
        cube.expandRowLevel(1).rowExpansion,
        cube.expandRowsToDepth(3).rowExpansion,
      );
      // a group expanded further down survives, unlike with expandRowsToDepth
      final drilled = cube.toggleRow(europe).toggleRow(germany);
      final all = drilled.expandRowLevel(0);
      expect(all.rowExpansion.isExpanded(germany), isTrue);
      expect(labels(all.layout.rows), [
        '∅',
        '∅',
        'Iceland',
        'Asia',
        'Japan',
        'Europe',
        '∅',
        'Germany',
        'A',
        'B',
        'Hungary',
        'Σ',
      ]);
      expect(
        drilled.expandRowsToDepth(2).rowExpansion.isExpanded(germany),
        isFalse,
      );
      // the last level cannot be expanded
      expect(cube.expandRowLevel(2).rowExpansion, cube.rowExpansion);
      expect(cube.expandRowLevel(-1).rowExpansion, cube.rowExpansion);
    });

    test('collapseRowLevel closes a whole level', () {
      final cube = Cube(
        facts: f,
        spec: CubeSpec(rows: CubeAxis.of([region, country, category])),
      ).expandRowLevel(1);
      expect(cube.layout.rows.length, 18);
      final countries = cube.collapseRowLevel(1);
      expect(countries.rowExpansion, cube.expandRowsToDepth(2).rowExpansion);
      expect(
        countries.collapseRowLevel(0).rowExpansion,
        ExpansionState.initial(),
      );
      expect(
        countries.collapseRowLevel(0).collapseRowLevel(0).rowExpansion,
        ExpansionState.initial(),
      );
    });

    test('rowsAddedByExpandingLevel counts without computing cells', () {
      final cube = Cube(
        facts: f,
        spec: CubeSpec(rows: CubeAxis.of([region, country])),
      );
      expect(cube.layout.rows.length, 4);
      expect(cube.rowsAddedByExpandingLevel(0), 6);
      expect(cube.expandRowLevel(0).layout.rows.length, 10);
      expect(cube.expandRowLevel(0).rowsAddedByExpandingLevel(0), 0);
      expect(cube.rowsAddedByExpandingLevel(1), 0);
      // a partly expanded axis only counts what is still closed
      final europe = p([const DimensionValue(region, 'Europe')]);
      expect(cube.toggleRow(europe).rowsAddedByExpandingLevel(0), 3);
      // hidden summary is not counted
      final hidden = Cube(
        facts: f,
        spec: CubeSpec(
          rows: CubeAxis.of([
            region,
            country,
          ], summaryPosition: SummaryPosition.hidden),
        ),
      );
      expect(hidden.layout.rows.length, 3);
      expect(hidden.rowsAddedByExpandingLevel(0), 6);
    });

    test('column level operations mirror the row ones', () {
      final cube = Cube(
        facts: f,
        spec: CubeSpec(columns: CubeAxis.of([region, country])),
      );
      expect(cube.columnsAddedByExpandingLevel(0), 6);
      final all = cube.expandColumnLevel(0);
      expect(all.layout.columns.length, 10);
      expect(
        all.collapseColumnLevel(0).columnExpansion,
        ExpansionState.initial(),
      );
    });

    test('changing the spec keeps the expansion where it still applies', () {
      final europe = p([const DimensionValue(region, 'Europe')]);
      final cube = Cube(
        facts: f,
        spec: CubeSpec(rows: CubeAxis.of([region, country])),
      ).toggleRow(europe);
      final swapped = cube.copyWith(
        spec: CubeSpec(rows: CubeAxis.of([region, category])),
      );
      expect(labels(swapped.layout.rows), [
        '∅',
        'Asia',
        'Europe',
        'A',
        'B',
        'Σ',
      ]);
      final reordered = cube.copyWith(
        spec: CubeSpec(rows: CubeAxis.of([country, region])),
      );
      expect(labels(reordered.layout.rows), [
        '∅',
        'Germany',
        'Hungary',
        'Iceland',
        'Japan',
        'Σ',
      ]);
    });
  });

  test('sales.csv: parents equal the sum of their children', () async {
    final file = File('test/data/sales.csv');
    final facts = (await loadFacts(CsvDataSource.fromBytes(file.openRead)))
        .facts;
    const total = Measure('total');
    final sum = Aggregate.sum(total);
    const salesRegion = ColumnDimension('region');
    const salesCountry = ColumnDimension('country');
    final cube = Cube(
      facts: facts,
      spec: CubeSpec(
        rows: CubeAxis.of([salesRegion, salesCountry]),
        columns: CubeAxis.of([const DatePartDimension('date', DatePart.year)]),
        aggregates: [sum, Aggregate.count],
      ),
    ).expandRowsToDepth(2);
    final l = cube.layout;

    var expectedTotal = 0.0;
    for (var r = 0; r < facts.rowCount; r++) {
      expectedTotal += facts.measureValue(r, total) ?? 0;
    }
    final grand = l.cellFor(DimensionPath.root, DimensionPath.root)!;
    expect(grand.factCount, 1000);
    expect(grand.aggregate(sum), closeTo(expectedTotal, 1e-6));
    expect(labels(l.columns), ['2024', '2025', 'Σ']);

    for (var j = 0; j < l.columns.length; j++) {
      var regionSum = 0.0, regionCount = 0;
      for (var i = 0; i < l.rows.length; i++) {
        final e = l.rows.entries[i];
        final cell = l.cellAt(i, j);
        if (e.depth == 1) {
          regionSum += cell.aggregate(sum) ?? 0;
          regionCount += cell.factCount;
          // region == sum over its countries
          var childSum = 0.0, childCount = 0;
          for (
            var k = i + 1;
            k < l.rows.length && l.rows.entries[k].depth == 2;
            k++
          ) {
            childSum += l.cellAt(k, j).aggregate(sum) ?? 0;
            childCount += l.cellAt(k, j).factCount;
          }
          expect(
            childSum,
            closeTo(cell.aggregate(sum) ?? 0, 1e-6),
            reason: '$e',
          );
          expect(childCount, cell.factCount, reason: '$e');
        }
      }
      final summary = l.cellAt(l.rows.length - 1, j);
      expect(regionSum, closeTo(summary.aggregate(sum)!, 1e-6));
      expect(regionCount, summary.factCount);
    }
    // Iceland lives under the empty region only.
    final noRegion = DimensionPath.root.child(
      const DimensionValue(salesRegion, null),
    );
    expect(
      l.rows.indexOf(
        noRegion.child(const DimensionValue(salesCountry, 'Iceland')),
      ),
      greaterThan(0),
    );
    expect(
      l.rows.indexOf(
        DimensionPath.root
            .child(const DimensionValue(salesRegion, 'Europe'))
            .child(const DimensionValue(salesCountry, 'Iceland')),
      ),
      -1,
    );
  });
}
