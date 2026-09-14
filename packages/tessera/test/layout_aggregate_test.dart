import 'package:test/test.dart';
import 'package:tessera/tessera.dart';

/// region, country, date, qty
const _rows = <List<Object?>>[
  ['Europe', 'Germany', '2024-01-05', 1],
  ['Europe', 'Hungary', '2024-03-05', 2],
  ['Europe', 'Germany', '2025-01-05', 4],
  ['Asia', 'Japan', '2024-06-05', 8],
  ['Asia', 'Japan', '2025-06-05', 16],
  [null, 'Iceland', '2024-02-01', 32],
];

Future<FactTable> facts() async {
  final source = ListDataSource(
    columns: ['region', 'country', 'date', 'qty'],
    rows: _rows,
    declaredSchema: Schema([
      const ColumnSpec(name: 'region', type: ColumnType.text),
      const ColumnSpec(name: 'country', type: ColumnType.text),
      const ColumnSpec(name: 'date', type: ColumnType.date),
      const ColumnSpec(name: 'qty', type: ColumnType.integer),
    ]),
  );
  return (await loadFacts(source)).facts;
}

const region = ColumnDimension('region');
const country = ColumnDimension('country');
const year = DatePartDimension('date', DatePart.year);
final sum = Aggregate.sum(const Measure('qty'));

void main() {
  late FactTable f;
  late Cube cube;
  late CubeLayout l;
  setUpAll(() async {
    f = await facts();
  });

  /// Builds the cube with [aggregates], Europe expanded; rows come out as
  /// null, Asia, Europe, Germany, Hungary, total; columns 2024, 2025, total.
  void build(List<Aggregate> aggregates) {
    cube = Cube(
      facts: f,
      spec: CubeSpec(
        rows: CubeAxis.of([region, country]),
        columns: CubeAxis.of([year]),
        aggregates: aggregates,
      ),
    ).toggleRow(const DimensionPath([DimensionValue(region, 'Europe')]));
    l = cube.layout;
    expect(l.rows.entries.map((e) => e.path.isRoot ? 'T' : e.value), [
      null,
      'Asia',
      'Europe',
      'Germany',
      'Hungary',
      'T',
    ]);
    expect(l.columns.entries.map((e) => e.path.isRoot ? 'T' : e.value), [
      2024,
      2025,
      'T',
    ]);
  }

  Object? at(int r, int c, Aggregate a) => l.cellAt(r, c).aggregate<Object?>(a);
  List<Object?> row(int r, Aggregate a) => [
    for (var c = 0; c < 3; c++) at(r, c, a),
  ];
  List<Object?> col(int c, Aggregate a) => [
    for (var r = 0; r < 6; r++) at(r, c, a),
  ];

  test('the base values', () {
    build([sum]);
    expect(row(0, sum), [32.0, null, 32.0]);
    expect(row(1, sum), [8.0, 16.0, 24.0]);
    expect(row(2, sum), [3.0, 4.0, 7.0]);
    expect(row(3, sum), [1.0, 4.0, 5.0]);
    expect(row(4, sum), [2.0, null, 2.0]);
    expect(row(5, sum), [43.0, 20.0, 63.0]);
  });

  test('percent of totals', () {
    final ofRow = Aggregate.percentOf(sum, TotalOf.row);
    final ofColumn = Aggregate.percentOf(sum, TotalOf.column);
    final ofGrand = Aggregate.percentOf(sum, TotalOf.grand);
    final ofParentRow = Aggregate.percentOf(sum, TotalOf.parentRow);
    final ofParentColumn = Aggregate.percentOf(sum, TotalOf.parentColumn);
    build([sum, ofRow, ofColumn, ofGrand, ofParentRow, ofParentColumn]);
    expect(row(2, ofRow), [
      closeTo(3 / 7 * 100, 1e-9),
      closeTo(4 / 7 * 100, 1e-9),
      100.0,
    ]);
    expect(row(0, ofRow), [100.0, null, 100.0]);
    expect(col(0, ofColumn), [
      closeTo(32 / 43 * 100, 1e-9),
      closeTo(8 / 43 * 100, 1e-9),
      closeTo(3 / 43 * 100, 1e-9),
      closeTo(1 / 43 * 100, 1e-9),
      closeTo(2 / 43 * 100, 1e-9),
      100.0,
    ]);
    expect(at(2, 0, ofGrand), closeTo(3 / 63 * 100, 1e-9));
    expect(at(5, 2, ofGrand), 100.0);
    // parent row: Germany within Europe, Europe within the total
    expect(row(3, ofParentRow), [
      closeTo(1 / 3 * 100, 1e-9),
      100.0,
      closeTo(5 / 7 * 100, 1e-9),
    ]);
    expect(at(2, 0, ofParentRow), closeTo(3 / 43 * 100, 1e-9));
    expect(row(5, ofParentRow), [null, null, null]);
    // parent column of a year is the row total
    expect(row(2, ofParentColumn), [
      closeTo(3 / 7 * 100, 1e-9),
      closeTo(4 / 7 * 100, 1e-9),
      null,
    ]);
    // an empty cell
    expect(at(4, 1, ofRow), isNull);
    expect(ofRow.id, 'percentOf(row, sum(qty))');
    expect(ofRow.label, 'sum of qty % of row total');
    expect(cube.layout.cellAt(2, 0).aggregates.keys, [
      sum,
      ofRow,
      ofColumn,
      ofGrand,
      ofParentRow,
      ofParentColumn,
    ]);
    expect(() => ofRow.createAccumulator(), throwsUnsupportedError);
  });

  test('difference from a sibling', () {
    final prevRow = Aggregate.differenceFrom(sum, axis: AxisSide.rows);
    final nextRow = Aggregate.differenceFrom(
      sum,
      axis: AxisSide.rows,
      item: BaseItem.next,
    );
    final prevCol = Aggregate.differenceFrom(sum, axis: AxisSide.columns);
    final fromAsia = Aggregate.differenceFrom(
      sum,
      axis: AxisSide.rows,
      item: const BaseItem.value('Asia'),
    );
    final pctPrevCol = Aggregate.percentDifferenceFrom(
      sum,
      axis: AxisSide.columns,
    );
    final fromMissing = Aggregate.differenceFrom(
      sum,
      axis: AxisSide.rows,
      item: const BaseItem.value('Mars'),
    );
    build([sum, prevRow, nextRow, prevCol, fromAsia, pctPrevCol, fromMissing]);
    // level-1 rows in display order: null, Asia, Europe
    expect(col(0, prevRow), [null, 8.0 - 32, 3.0 - 8, null, 2.0 - 1, null]);
    expect(col(0, nextRow), [32.0 - 8, 8.0 - 3, null, 1.0 - 2, null, null]);
    expect(row(2, prevCol), [null, 4.0 - 3, null]);
    expect(row(4, prevCol), [null, null, null]); // Hungary has no 2025
    expect(col(0, fromAsia), [32.0 - 8, 0.0, 3.0 - 8, null, null, null]);
    expect(row(2, pctPrevCol), [null, closeTo((4 - 3) / 3 * 100, 1e-9), null]);
    expect(row(1, pctPrevCol), [null, 100.0, null]);
    expect(col(0, fromMissing), [null, null, null, null, null, null]);
    expect(prevRow.id, 'differenceFrom(rows.previous, sum(qty))');
    expect(fromAsia.id, 'differenceFrom(rows.value:Asia, sum(qty))');
    expect(pctPrevCol.label, 'sum of qty % difference from previous');
    expect(
      fromAsia,
      Aggregate.differenceFrom(
        sum,
        axis: AxisSide.rows,
        item: const BaseItem.value('Asia'),
      ),
    );
  });

  test('running total and rank', () {
    final runRows = Aggregate.runningTotal(sum, axis: AxisSide.rows);
    final runCols = Aggregate.runningTotal(sum, axis: AxisSide.columns);
    final rankRows = Aggregate.rank(sum, axis: AxisSide.rows);
    final rankRowsAsc = Aggregate.rank(
      sum,
      axis: AxisSide.rows,
      ascending: true,
    );
    final rankCols = Aggregate.rank(sum, axis: AxisSide.columns);
    build([sum, runRows, runCols, rankRows, rankRowsAsc, rankCols]);
    expect(col(0, runRows), [32.0, 40.0, 43.0, 1.0, 3.0, 43.0]);
    expect(col(1, runRows), [null, 16.0, 20.0, 4.0, 4.0, 20.0]);
    expect(row(2, runCols), [3.0, 7.0, 7.0]);
    expect(row(0, runCols), [32.0, 32.0, 32.0]);
    expect(col(0, rankRows), [1, 2, 3, 2, 1, null]);
    expect(col(0, rankRowsAsc), [3, 2, 1, 1, 2, null]);
    expect(col(1, rankRows), [null, 1, 2, 1, null, null]);
    expect(row(2, rankCols), [2, 1, null]);
    expect(rankRowsAsc.id, 'rank(rows.ascending, sum(qty))');
    expect(runRows.label, 'sum of qty running total');
  });

  test('ties share a rank', () async {
    final tied = await (() async {
      final source = ListDataSource(
        columns: ['g', 'x'],
        rows: [
          ['a', 5],
          ['b', 5],
          ['c', 3],
          ['d', 5],
        ],
        declaredSchema: Schema([
          const ColumnSpec(name: 'g', type: ColumnType.text),
          const ColumnSpec(name: 'x', type: ColumnType.integer),
        ]),
      );
      return (await loadFacts(source)).facts;
    })();
    final s = Aggregate.sum(const Measure('x'));
    final rank = Aggregate.rank(s, axis: AxisSide.rows);
    final c = Cube(
      facts: tied,
      spec: CubeSpec(
        rows: CubeAxis.of([const ColumnDimension('g')]),
        aggregates: [rank],
      ),
    );
    expect(
      [for (var r = 0; r < 4; r++) c.layout.cellAt(r, 0).aggregate(rank)],
      [1, 1, 4, 1],
    );
  });

  test('layout aggregates over derived and other layout aggregates', () {
    final doubled = Aggregate.expression('sum(qty) * 2');
    final pct = Aggregate.percentOf(doubled, TotalOf.row);
    final runOfPct = Aggregate.runningTotal(pct, axis: AxisSide.columns);
    build([pct, runOfPct]);
    expect(row(2, pct), [
      closeTo(3 / 7 * 100, 1e-9),
      closeTo(4 / 7 * 100, 1e-9),
      100.0,
    ]);
    expect(row(2, runOfPct), [closeTo(3 / 7 * 100, 1e-9), 100.0, 100.0]);
    // the base need not be in the spec, but it is readable as a dependency
    expect(at(2, 0, sum), 3.0);
  });

  test('sorting by a layout aggregate sorts by its base', () {
    final pct = Aggregate.percentOf(sum, TotalOf.column);
    final c = Cube(
      facts: f,
      spec: CubeSpec(
        rows: CubeAxis(
          dimensions: [
            AxisDimension(
              region,
              sort: AxisSort(
                by: SortBy.aggregate,
                aggregate: pct,
                direction: SortDirection.descending,
              ),
            ),
          ],
        ),
        aggregates: [pct],
      ),
    );
    expect(c.layout.rows.entries.map((e) => e.path.isRoot ? 'T' : e.value), [
      null,
      'Asia',
      'Europe',
      'T',
    ]);
  });

  test('labels are localized', () async {
    final en = const TesseraStringsEn();
    final hu = const TesseraStringsHu();
    expect(
      en.aggregateLabel(Aggregate.percentOf(sum, TotalOf.row), f),
      'sum of qty % of row total',
    );
    expect(
      en.aggregateLabel(Aggregate.percentOf(sum, TotalOf.parentColumn), f),
      'sum of qty % of parent column',
    );
    expect(
      en.aggregateLabel(Aggregate.differenceFrom(sum, axis: AxisSide.rows), f),
      'sum of qty difference from previous',
    );
    expect(
      en.aggregateLabel(
        Aggregate.percentDifferenceFrom(
          sum,
          axis: AxisSide.rows,
          item: BaseItem.next,
        ),
        f,
      ),
      'sum of qty % difference from next',
    );
    expect(
      en.aggregateLabel(
        Aggregate.differenceFrom(
          sum,
          axis: AxisSide.rows,
          item: const BaseItem.value(2024),
        ),
        f,
      ),
      'sum of qty difference from 2024',
    );
    expect(
      en.aggregateLabel(
        Aggregate.differenceFrom(
          sum,
          axis: AxisSide.rows,
          item: const BaseItem.value(null),
        ),
        f,
      ),
      'sum of qty difference from (empty)',
    );
    expect(
      en.aggregateLabel(Aggregate.runningTotal(sum, axis: AxisSide.rows), f),
      'sum of qty running total',
    );
    expect(
      en.aggregateLabel(Aggregate.rank(sum, axis: AxisSide.rows), f),
      'sum of qty rank',
    );
    expect(
      hu.aggregateLabel(Aggregate.percentOf(sum, TotalOf.row), f),
      'qty összege a sor összegének %-ában',
    );
    expect(
      hu.aggregateLabel(Aggregate.runningTotal(sum, axis: AxisSide.rows), f),
      'qty összege göngyölítve',
    );
    for (final code in TesseraStrings.supportedLanguages) {
      final s = TesseraStrings.forLanguage(code)!;
      final labels = {
        for (final of in TotalOf.values)
          s.aggregateLabel(Aggregate.percentOf(sum, of), f),
        s.aggregateLabel(Aggregate.differenceFrom(sum, axis: AxisSide.rows), f),
        s.aggregateLabel(
          Aggregate.differenceFrom(
            sum,
            axis: AxisSide.rows,
            item: BaseItem.next,
          ),
          f,
        ),
        s.aggregateLabel(
          Aggregate.percentDifferenceFrom(sum, axis: AxisSide.rows),
          f,
        ),
        s.aggregateLabel(Aggregate.runningTotal(sum, axis: AxisSide.rows), f),
        s.aggregateLabel(Aggregate.rank(sum, axis: AxisSide.rows), f),
      };
      expect(labels.length, 10, reason: code);
      expect(
        labels.every((x) => x.contains(s.sumOf('qty'))),
        isTrue,
        reason: code,
      );
    }
  });
}
