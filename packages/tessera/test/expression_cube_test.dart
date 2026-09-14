import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:tessera/tessera.dart';

/// region, country, date, qty, price, active
const _rows = <List<Object?>>[
  ['Europe', 'Germany', '2024-01-05', 1, 10.0, true],
  ['Europe', 'Hungary', '2024-03-05', 2, 20.0, false],
  ['Europe', null, '2025-01-05', 3, null, null],
  ['Asia', 'Japan', '2025-06-05', 5, 50.0, true],
  [null, 'Iceland', null, null, 70.0, false],
];

Future<FactTable> facts() async {
  final source = ListDataSource(
    columns: ['region', 'country', 'date', 'qty', 'price', 'active'],
    rows: _rows,
    declaredSchema: Schema([
      const ColumnSpec(name: 'region', type: ColumnType.text),
      const ColumnSpec(name: 'country', type: ColumnType.text),
      const ColumnSpec(name: 'date', type: ColumnType.date),
      const ColumnSpec(name: 'qty', type: ColumnType.integer),
      const ColumnSpec(name: 'price', type: ColumnType.number),
      const ColumnSpec(name: 'active', type: ColumnType.boolean),
    ]),
  );
  return (await loadFacts(source)).facts;
}

const region = ColumnDimension('region');
const qty = Measure('qty');
const price = Measure('price');

List<Object?> rowLabels(Cube cube) => [
  for (final e in cube.layout.rows.entries) e.path.isRoot ? 'total' : e.value,
];

Object? cellOf(Cube cube, int row, Aggregate a) =>
    cube.layout.cellAt(row, 0).aggregate<Object?>(a);

void main() {
  late FactTable f;
  setUpAll(() async => f = await facts());

  group('filters', () {
    Set<int> rowsOf(FactFilter filter) => {
      for (var r = 0; r < f.rowCount; r++)
        if (filter.matches(f, r)) r,
    };

    test('ExpressionFilter matches and compiles once per table', () {
      final filter = ExpressionFilter('qty >= 2 and price is not empty');
      expect(rowsOf(filter), {1, 3});
      expect(identical(filter.compile(f), filter.compile(f)), isTrue);
      expect(filter, ExpressionFilter('qty >= 2 and price is not empty'));
      expect(filter.toExpressionSource(), 'qty >= 2 and price is not empty');
      // unknown (null) is excluded
      expect(rowsOf(ExpressionFilter('price > 15')), {1, 3, 4});
      expect(rowsOf(ExpressionFilter('not (price > 15)')), {0});
    });

    test('ExpressionFilter errors', () {
      expect(
        () => ExpressionFilter('qty +').compile(f),
        throwsA(isA<ExpressionError>()),
      );
      expect(
        () => ExpressionFilter('qty + 1').compile(f),
        throwsA(
          isA<ExpressionError>().having(
            (e) => e.kind,
            'kind',
            ExpressionErrorKind.resultType,
          ),
        ),
      );
      expect(
        () => ExpressionFilter('nope = 1').compile(f),
        throwsA(isA<ExpressionError>()),
      );
      expect(
        Expression.validate(
          'qty > 1',
          scope: ExpressionScope.ofFacts(f),
          expected: ExprType.boolean,
        ),
        isNull,
      );
      expect(
        Expression.validate(
          'qty > 1',
          scope: ExpressionScope.ofSchema(f.schema),
          expected: ExprType.boolean,
        ),
        isNull,
      );
    });

    test('in a cube', () {
      final cube = Cube(
        facts: f,
        spec: CubeSpec(
          rows: const CubeAxis(
            dimensions: [AxisDimension(region)],
            summaryPosition: SummaryPosition.start,
          ),
          aggregates: [Aggregate.sum(qty)],
          filter: ExpressionFilter('year(date) = 2024 or country = "Japan"'),
        ),
      );
      expect(rowLabels(cube), ['total', 'Asia', 'Europe']);
      expect(cellOf(cube, 0, Aggregate.sum(qty)), 8.0);
      expect(cellOf(cube, 1, Aggregate.sum(qty)), 5.0);
      expect(cellOf(cube, 2, Aggregate.sum(qty)), 3.0);
    });

    test('structured filters match through expressions', () {
      expect(rowsOf(CompareFilter('qty', CompareOp.greater, 2)), {2, 3});
      expect(rowsOf(CompareFilter('region', CompareOp.equal, 'Asia')), {3});
      expect(rowsOf(CompareFilter('region', CompareOp.notEqual, 'Asia')), {
        0,
        1,
        2,
      });
      expect(rowsOf(CompareFilter('active', CompareOp.equal, true)), {0, 3});
      expect(
        rowsOf(
          CompareFilter(
            'date',
            CompareOp.lessOrEqual,
            DateTime.utc(2024, 3, 5),
          ),
        ),
        {0, 1},
      );
      expect(rowsOf(RangeFilter('qty', 2, 3)), {1, 2});
      expect(
        rowsOf(
          RangeFilter(
            'date',
            DateTime.utc(2025, 1, 1),
            DateTime.utc(2025, 12, 31),
          ),
        ),
        {2, 3},
      );
      expect(rowsOf(TextFilter('country', TextMatch.contains, 'an')), {
        0,
        3,
        4,
      });
      expect(rowsOf(TextFilter('country', TextMatch.startsWith, 'I')), {4});
      expect(rowsOf(TextFilter('country', TextMatch.endsWith, 'y')), {0, 1});
      expect(rowsOf(EmptyFilter('price')), {2});
      expect(rowsOf(EmptyFilter('region', negated: true)), {0, 1, 2, 3});
      expect(
        rowsOf(
          AndFilter([
            CompareFilter('qty', CompareOp.greater, 1),
            EmptyFilter('active', negated: true),
          ]),
        ),
        {1, 3},
      );
      expect(rowsOf(OrFilter([EmptyFilter('qty'), EmptyFilter('price')])), {
        2,
        4,
      });
      expect(rowsOf(NotFilter(EmptyFilter('qty'))), {0, 1, 2, 3});
    });

    test('structured filters render to expressions', () {
      expect(
        CompareFilter('qty', CompareOp.greater, 2).toExpressionSource(),
        'qty > 2',
      );
      expect(
        CompareFilter('unit price', CompareOp.equal, 1.5).toExpressionSource(),
        '[unit price] = 1.5',
      );
      expect(
        CompareFilter('region', CompareOp.notEqual, 'A"b').toExpressionSource(),
        'region <> "A""b"',
      );
      expect(
        CompareFilter(
          'date',
          CompareOp.less,
          DateTime.utc(2024, 1, 2),
        ).toExpressionSource(),
        'date < #2024-01-02#',
      );
      expect(
        CompareFilter(
          'date',
          CompareOp.less,
          DateTime.utc(2024, 1, 2, 10, 30),
        ).toExpressionSource(),
        'date < #2024-01-02 10:30:00#',
      );
      expect(
        RangeFilter('qty', 1, 2.5).toExpressionSource(),
        'qty between 1 and 2.5',
      );
      expect(
        TextFilter('country', TextMatch.contains, 'x').toExpressionSource(),
        'contains(country, "x")',
      );
      expect(EmptyFilter('and').toExpressionSource(), '[and] is empty');
      expect(
        EmptyFilter('x', negated: true).toExpressionSource(),
        'x is not empty',
      );
      expect(
        AndFilter([
          CompareFilter('qty', CompareOp.greater, 2),
          OrFilter([
            EmptyFilter('price'),
            TextFilter('country', TextMatch.endsWith, 'y'),
          ]),
        ]).toExpressionSource(),
        '(qty > 2 and (price is empty or endswith(country, "y")))',
      );
      expect(
        NotFilter(EmptyFilter('qty')).toExpressionSource(),
        'not qty is empty',
      );
      // a free-form expression keeps its own precedence in a combination
      expect(
        AndFilter([
          EmptyFilter('qty'),
          ExpressionFilter('price > 1 or qty > 1'),
        ]).toExpressionSource(),
        '(qty is empty and (price > 1 or qty > 1))',
      );
      expect(
        NotFilter(ExpressionFilter('price > 1 or qty > 1'))
            .toExpressionSource(),
        'not (price > 1 or qty > 1)',
      );
      expect(const AndFilter([]).toExpressionSource(), 'true');
      expect(const OrFilter([]).toExpressionSource(), 'false');
      expect(
        ValueFilter(region, ['Asia', 'Europe']).toExpressionSource(),
        'region in ("Asia", "Europe")',
      );
      expect(
        ValueFilter(region, ['Asia', null]).toExpressionSource(),
        '(region is empty or region in ("Asia"))',
      );
      expect(
        ValueFilter(region, [null]).toExpressionSource(),
        'region is empty',
      );
      expect(ValueFilter(region, []).toExpressionSource(), 'false');
      expect(
        ValueFilter(const DatePartDimension('date', DatePart.year), [
          2024,
        ]).toExpressionSource(),
        'year(date) in (2024)',
      );
      expect(
        ValueFilter(ExpressionDimension('qty * 2'), [4]).toExpressionSource(),
        '(qty * 2) in (4)',
      );
      expect(
        ValueFilter(
          MappedDimension(id: 'm', sourceColumn: 'qty', map: (v) => v),
          [1],
        ).toExpressionSource(),
        isNull,
      );
      expect(PredicateFilter((_, _) => true).toExpressionSource(), isNull);
      expect(
        AndFilter([EmptyFilter('qty'), PredicateFilter((_, _) => true)])
            .toExpressionSource(),
        isNull,
      );
      // the rendered expression matches the same rows
      for (final filter in [
        ValueFilter(region, ['Asia', null]),
        ValueFilter(const DatePartDimension('date', DatePart.year), [2024]),
        AndFilter([
          CompareFilter('qty', CompareOp.greater, 1),
          NotFilter(EmptyFilter('active')),
        ]),
      ]) {
        expect(
          rowsOf(ExpressionFilter(filter.toExpressionSource()!)),
          rowsOf(filter),
          reason: filter.toString(),
        );
      }
    });

    test('structured filters are values', () {
      expect(
        CompareFilter('qty', CompareOp.greater, 2),
        CompareFilter('qty', CompareOp.greater, 2),
      );
      expect(
        CompareFilter('qty', CompareOp.greater, 2),
        isNot(CompareFilter('qty', CompareOp.greater, 3)),
      );
      expect(
        CompareFilter('qty', CompareOp.greater, 2).hashCode,
        CompareFilter('qty', CompareOp.greater, 2).hashCode,
      );
      expect(EmptyFilter('x'), isNot(CompareFilter('x', CompareOp.equal, 1)));
      expect(literalSource(null), 'null');
      expect(literalSource(3), '3');
      expect(literalSource(2.5), '2.5');
      expect(literalSource(true), 'true');
      expect(literalSource('a'), '"a"');
      expect(literalSource(DateTime.utc(2024, 5, 6)), '#2024-05-06#');
    });
  });

  group('ExpressionMeasure', () {
    test('is aggregated like a column', () {
      final total = Measure.expression('qty * price', label: 'total');
      expect(total.id, 'qty * price');
      expect(total.label, 'total');
      expect(total.labelFor(f), 'total');
      expect(total.columns, {'qty', 'price'});
      expect(Measure.expression('qty', id: 'q').id, 'q');
      expect(Measure.expression('qty').label, 'qty');
      expect(total, Measure.expression('qty * price'));
      expect(total, isNot(const Measure('qty')));
      expect(const Measure('qty'), const ColumnMeasure('qty'));
      expect(const Measure('qty').columns, {'qty'});
      expect(f.measureValue(0, total), 10.0);
      expect(f.measureValue(2, total), isNull);
      final cube = Cube(
        facts: f,
        spec: CubeSpec(
          rows: const CubeAxis(
            dimensions: [AxisDimension(region)],
            summaryPosition: SummaryPosition.start,
          ),
          aggregates: [
            Aggregate.sum(total),
            Aggregate.average(total),
            Aggregate.max(total),
            Aggregate.countNonNull(total),
          ],
        ),
      );
      expect(cellOf(cube, 0, Aggregate.sum(total)), 300.0);
      expect(cellOf(cube, 0, Aggregate.average(total)), 100.0);
      expect(cellOf(cube, 0, Aggregate.max(total)), 250.0);
      expect(cellOf(cube, 0, Aggregate.countNonNull(total)), 3);
      expect(rowLabels(cube), ['total', null, 'Asia', 'Europe']);
      expect(cellOf(cube, 1, Aggregate.sum(total)), isNull);
      expect(cellOf(cube, 2, Aggregate.sum(total)), 250.0);
      expect(cellOf(cube, 3, Aggregate.sum(total)), 50.0);
      expect(
        const TesseraStringsEn().aggregateLabel(Aggregate.sum(total), f),
        'sum of total',
      );
    });

    test('errors', () {
      expect(
        () => Measure.expression('qty +'),
        throwsA(isA<ExpressionError>()),
      );
      expect(
        () => f.measureValue(0, Measure.expression('region')),
        throwsA(isA<ExpressionError>()),
      );
      expect(
        () => f.measureValue(0, Measure.expression('nope')),
        throwsA(isA<ExpressionError>()),
      );
    });
  });

  group('ExpressionDimension', () {
    test('text', () {
      final size = ExpressionDimension(
        'if(qty > 2, "big", "small")',
        label: 'size',
      );
      expect(size.id, 'if(qty > 2, "big", "small")');
      expect(size.label, 'size');
      expect(size.explicitLabel, 'size');
      expect(size.sourceColumns, ['qty']);
      expect(size.sourceColumn, 'qty');
      expect(ExpressionDimension('1').sourceColumn, '');
      expect(ExpressionDimension('price - qty').sourceColumns, [
        'price',
        'qty',
      ]);
      expect(f.dimensionValue(0, size), 'small');
      expect(f.dimensionValue(3, size), 'big');
      expect(f.dimensionValue(4, size), 'small');
      expect(f.distinctValues(size), ['big', 'small']);
      expect(f.countWhere(size, 'big'), 2);
      final cube = Cube(
        facts: f,
        spec: CubeSpec(
          rows: CubeAxis(
            dimensions: [AxisDimension(size)],
            summaryPosition: SummaryPosition.start,
          ),
          aggregates: [Aggregate.sum(qty)],
        ),
      );
      expect(rowLabels(cube), ['total', 'big', 'small']);
      expect(cellOf(cube, 1, Aggregate.sum(qty)), 8.0);
      expect(cellOf(cube, 2, Aggregate.sum(qty)), 3.0);
    });

    test('number, date and boolean values, formatted', () {
      final half = ExpressionDimension('price / 20');
      expect(f.dimensionValue(0, half), 0.5);
      expect(f.dimensionValue(2, half), isNull);
      expect(half.formatValue(0.5), '0.5');
      final whole = ExpressionDimension('qty * 2');
      expect(f.dimensionValue(1, whole), 4);
      expect(whole.formatValue(f.dimensionValue(1, whole)), '4');
      final month = ExpressionDimension('date - day(date) + 1', label: 'month');
      expect(f.dimensionValue(1, month), DateTime.utc(2024, 3, 1));
      expect(month.formatValue(f.dimensionValue(1, month)), '2024-03-01');
      expect(f.distinctValues(month), [
        null,
        DateTime.utc(2024, 1, 1),
        DateTime.utc(2024, 3, 1),
        DateTime.utc(2025, 1, 1),
        DateTime.utc(2025, 6, 1),
      ]);
      final flag = ExpressionDimension('qty > 2');
      expect(f.dimensionValue(0, flag), false);
      expect(f.dimensionValue(3, flag), true);
      expect(f.dimensionValue(4, flag), isNull);
      expect(f.distinctValues(flag), [null, false, true]);
      final cube = Cube(
        facts: f,
        spec: CubeSpec(
          rows: CubeAxis(
            dimensions: [AxisDimension(month), AxisDimension(flag)],
            summaryPosition: SummaryPosition.start,
          ),
          aggregates: [Aggregate.count],
        ),
      ).expandRowsToDepth(2);
      expect(rowLabels(cube), [
        'total',
        null,
        null,
        DateTime.utc(2024, 1, 1),
        false,
        DateTime.utc(2024, 3, 1),
        false,
        DateTime.utc(2025, 1, 1),
        true,
        DateTime.utc(2025, 6, 1),
        true,
      ]);
    });

    test('with a filter and a column dimension side by side', () {
      final cube = Cube(
        facts: f,
        spec: CubeSpec(
          rows: CubeAxis(
            dimensions: [
              AxisDimension(ExpressionDimension('upper(left(region, 2))')),
            ],
            summaryPosition: SummaryPosition.start,
          ),
          columns: const CubeAxis(
            dimensions: [AxisDimension(ColumnDimension('active'))],
            summaryPosition: SummaryPosition.start,
          ),
          aggregates: [Aggregate.sum(qty)],
          filter: ExpressionFilter('qty is not empty'),
        ),
      );
      expect(rowLabels(cube), ['total', 'AS', 'EU']);
      expect(
        cube.layout.columns.entries.map(
          (e) => e.path.isRoot ? 'total' : e.value,
        ),
        ['total', null, false, true],
      );
      expect(
        cube.layout
            .cellFor(
              cube.layout.rows.entries[2].path,
              cube.layout.columns.entries[3].path,
            )!
            .aggregate(Aggregate.sum(qty)),
        1.0,
      );
    });

    test('errors', () {
      expect(() => ExpressionDimension('('), throwsA(isA<ExpressionError>()));
      expect(
        () => f.dimensionValue(0, ExpressionDimension('nope')),
        throwsA(isA<ExpressionError>()),
      );
    });
  });

  group('ExpressionAggregate', () {
    test('computes from dependencies the spec need not list', () {
      final avgPrice = Aggregate.expression(
        'sum(price) / count(price)',
        label: 'avg price',
      );
      expect(avgPrice.id, 'sum(price) / count(price)');
      expect(avgPrice.label, 'avg price');
      expect(avgPrice.dependencies, [
        Aggregate.sum(price),
        Aggregate.countNonNull(price),
      ]);
      expect(Aggregate.expression('count').dependencies, [Aggregate.count]);
      expect(Aggregate.expression('count()').dependencies, [Aggregate.count]);
      expect(
        Aggregate.expression(
          'distinct(region) + min(qty) - max(qty) + avg(qty) + average(qty)',
        ).dependencies,
        [
          Aggregate.distinctCount(region),
          Aggregate.min(qty),
          Aggregate.max(qty),
          Aggregate.average(qty),
        ],
      );
      expect(Aggregate.expression('min(1, 2)').dependencies, isEmpty);
      expect(() => avgPrice.createAccumulator(), throwsUnsupportedError);
      final cube = Cube(
        facts: f,
        spec: CubeSpec(
          rows: const CubeAxis(
            dimensions: [AxisDimension(region)],
            summaryPosition: SummaryPosition.start,
          ),
          aggregates: [avgPrice, Aggregate.count],
        ),
      );
      expect(cellOf(cube, 0, avgPrice), 37.5);
      expect(rowLabels(cube), ['total', null, 'Asia', 'Europe']);
      expect(cellOf(cube, 1, avgPrice), 70.0);
      expect(cellOf(cube, 2, avgPrice), 50.0);
      expect(cellOf(cube, 3, avgPrice), 15.0);
      expect(cube.layout.cellAt(0, 0).aggregates, {
        avgPrice: 37.5,
        Aggregate.count: 5,
      });
      // dependencies are readable too, other aggregates are not
      expect(cellOf(cube, 0, Aggregate.sum(price)), 150.0);
      expect(() => cellOf(cube, 0, Aggregate.sum(qty)), throwsArgumentError);
    });

    test('null and division by zero', () {
      final ratio = Aggregate.expression('sum(qty) / (sum(price) - 150)');
      final cube = Cube(
        facts: f,
        spec: CubeSpec(
          rows: const CubeAxis(
            dimensions: [AxisDimension(region)],
            summaryPosition: SummaryPosition.start,
          ),
          aggregates: [ratio],
          filter: ExpressionFilter('region is not empty'),
        ),
      );
      // total: sum(price) = 80 → 11 / -70
      expect(cellOf(cube, 0, ratio), closeTo(-0.157, 0.001));
      final nothing = Cube(
        facts: f,
        spec: CubeSpec(
          rows: const CubeAxis(
            dimensions: [AxisDimension(region)],
            summaryPosition: SummaryPosition.start,
          ),
          aggregates: [
            Aggregate.expression('sum(price) / (sum(price) - 150)'),
            Aggregate.expression('sum(qty) / 0'),
          ],
        ),
      );
      expect(nothing.layout.cellAt(0, 0).aggregates.values, [null, null]);
      // an empty cell
      final empty = Cube(
        facts: f,
        spec: CubeSpec(
          rows: const CubeAxis(
            dimensions: [AxisDimension(region)],
            summaryPosition: SummaryPosition.start,
          ),
          columns: const CubeAxis(
            dimensions: [AxisDimension(ColumnDimension('country'))],
          ),
          aggregates: [ratio, Aggregate.count],
        ),
      );
      final asia = empty.layout.rows.entries.indexWhere(
        (e) => e.value == 'Asia',
      );
      final germany = empty.layout.columns.entries.indexWhere(
        (e) => e.value == 'Germany',
      );
      final cell = empty.layout.cellAt(asia, germany);
      expect(cell.isEmpty, isTrue);
      expect(cell.aggregate(ratio), isNull);
      expect(cell.aggregate(Aggregate.count), 0);
    });

    test('sorting by a derived aggregate', () {
      final perFact = Aggregate.expression('sum(price) / count');
      final cube = Cube(
        facts: f,
        spec: CubeSpec(
          rows: CubeAxis(
            dimensions: [
              AxisDimension(
                region,
                sort: AxisSort(
                  by: SortBy.aggregate,
                  aggregate: perFact,
                  direction: SortDirection.descending,
                ),
              ),
            ],
            summaryPosition: SummaryPosition.start,
          ),
          aggregates: [perFact],
        ),
      );
      // Europe 30/3 = 10, Asia 50/1 = 50, null 70/1 = 70
      expect(rowLabels(cube), ['total', null, 'Asia', 'Europe']);
    });

    test('functions in a cell formula and custom functions', () {
      final fns = FunctionRegistry.standard().withFunction(
        ExpressionFunction(
          'pct',
          parameters: [ExprType.number, ExprType.number],
          returns: ExprType.number,
          implementation: (a) {
            final x = a[0] as double?, y = a[1] as double?;
            return x == null || y == null || y == 0 ? null : x / y * 100;
          },
        ),
      );
      final share = Aggregate.expression(
        'round(pct(count(price), count), 1)',
        functions: fns,
      );
      final cube = Cube(
        facts: f,
        spec: CubeSpec(
          rows: const CubeAxis(
            dimensions: [AxisDimension(region)],
            summaryPosition: SummaryPosition.start,
          ),
          aggregates: [share],
        ),
      );
      expect(cellOf(cube, 0, share), 80.0);
      expect(cellOf(cube, 3, share), closeTo(66.7, 0.01));
    });

    test('errors', () {
      expect(
        () => Aggregate.expression('sum('),
        throwsA(isA<ExpressionError>()),
      );
      final bad = Aggregate.expression('sum(region)');
      final cube = Cube(
        facts: f,
        spec: CubeSpec(
          rows: const CubeAxis(
            dimensions: [AxisDimension(region)],
            summaryPosition: SummaryPosition.start,
          ),
          aggregates: [bad],
        ),
      );
      expect(() => cube.layout, throwsA(isA<ExpressionError>()));
      final unknown = Aggregate.expression('sum(nope)');
      expect(
        () => Cube(
          facts: f,
          spec: CubeSpec(
            rows: const CubeAxis(
              dimensions: [AxisDimension(region)],
              summaryPosition: SummaryPosition.start,
            ),
            aggregates: [unknown],
          ),
        ).layout,
        throwsA(
          isA<ExpressionError>().having(
            (e) => e.kind,
            'kind',
            ExpressionErrorKind.unknownColumn,
          ),
        ),
      );
      expect(
        Expression.validate(
          'sum(qty) / count',
          scope: ExpressionScope.cellsOf(f),
          expected: ExprType.number,
        ),
        isNull,
      );
    });

    test('aggregates over row expressions', () {
      final weighted = Aggregate.expression(
        'sum(qty * price) / sum(qty)',
        label: 'weighted price',
      );
      expect(weighted.dependencies, [
        Aggregate.sum(Measure.expression('qty * price')),
        Aggregate.sum(qty),
      ]);
      expect(weighted.dependencies.first.id, 'sum(qty * price)');
      final spread = Aggregate.expression('max(price - qty) - min(price-qty)');
      expect(spread.dependencies, [
        Aggregate.max(Measure.expression('price - qty')),
        Aggregate.min(Measure.expression('price - qty')),
      ]);
      expect(spread.dependencies.first.id, 'max(price - qty)');
      // min/max over an aggregate expression stay the plain functions
      final identity = Aggregate.expression(
        'min(sum(qty)) + max(sum(qty) * 2)',
      );
      expect(identity.dependencies, [Aggregate.sum(qty)]);
      final initials = Aggregate.expression(
        'distinct(upper(left(country, 1)))',
      );
      expect(initials.dependencies, [
        Aggregate.distinctCount(ExpressionDimension('upper(left(country, 1))')),
      ]);
      final sd = Aggregate.expression('stdevp(qty * 2)');
      final cube = Cube(
        facts: f,
        spec: CubeSpec(
          rows: const CubeAxis(
            dimensions: [AxisDimension(region)],
            summaryPosition: SummaryPosition.start,
          ),
          aggregates: [weighted, spread, identity, initials, sd],
        ),
      );
      // total: (10 + 40 + 250) / (1 + 2 + 3 + 5); the row without a price
      // still has a quantity
      expect(cellOf(cube, 0, weighted), closeTo(300 / 11, 1e-12));
      // Europe: (10 + 40) / (1 + 2 + 3)
      expect(cellOf(cube, 3, weighted), closeTo(50 / 6, 1e-12));
      // price - qty over the total: 9, 18, null, 45, null → 45 − 9
      expect(cellOf(cube, 0, spread), 36.0);
      expect(cellOf(cube, 0, identity), 11.0 + 22.0);
      // G, H, J, I
      expect(cellOf(cube, 0, initials), 4.0);
      expect(cellOf(cube, 3, initials), 2.0);
      // population std dev of 2, 4, 6, 10 = sqrt(((3)²+(1.5)²... )) computed below
      final values = [2.0, 4.0, 6.0, 10.0];
      final mean = values.reduce((a, b) => a + b) / 4;
      final m2 = values.fold(0.0, (a, v) => a + (v - mean) * (v - mean));
      expect(cellOf(cube, 0, sd), closeTo(math.sqrt(m2 / 4), 1e-12));
      // custom functions reach into the argument
      final fns = FunctionRegistry.standard().withFunction(
        ExpressionFunction(
          'twice',
          parameters: [ExprType.number],
          returns: ExprType.number,
          implementation: (a) => a[0] == null ? null : (a[0] as double) * 2,
        ),
      );
      final doubled = Aggregate.expression('sum(twice(qty))', functions: fns);
      final c2 = Cube(
        facts: f,
        spec: CubeSpec(aggregates: [doubled]),
      );
      expect(c2.layout.cellAt(0, 0).aggregate(doubled), 22.0);
    });

    test('errors in aggregate arguments point into the argument', () {
      (ExpressionErrorKind, int, String) err(String s) {
        final e = Expression.validate(
          s,
          scope: ExpressionScope.cellsOf(f),
          expected: ExprType.number,
        )!;
        return (e.kind, e.offset, e.arguments.join(','));
      }

      expect(err('sum(nope + 1)'), (
        ExpressionErrorKind.unknownColumn,
        4,
        'nope',
      ));
      expect(err('sum(country)').$1, ExpressionErrorKind.argumentType);
      expect(err('sum(len(country) + region)'), (
        ExpressionErrorKind.operandType,
        19,
        '+,number,text',
      ));
      expect(err('sum(sum(qty))'), (
        ExpressionErrorKind.argumentType,
        4,
        'sum,1,a column or a row expression,an expression over aggregates',
      ));
      expect(err('avg(qty > 1)'), (
        ExpressionErrorKind.argumentType,
        4,
        'avg,1,number,boolean',
      ));
      expect(err('distinct(null)').$1, ExpressionErrorKind.unknownType);
      expect(err('min(country)').$1, ExpressionErrorKind.argumentType);
      expect(err('count(qty, price)').$1, ExpressionErrorKind.argumentCount);
      expect(
        Expression.validate(
          'sum(qty * 2) / count(price * 0 + 1)',
          scope: ExpressionScope.cellsOf(f),
          expected: ExprType.number,
        ),
        isNull,
      );
      expect(
        () => Aggregate.expression('sum(qty)').compute((_) => 1.0),
        throwsStateError,
      );
    });

    test('a custom DerivedAggregate', () {
      final cube = Cube(
        facts: f,
        spec: CubeSpec(
          rows: const CubeAxis(
            dimensions: [AxisDimension(region)],
            summaryPosition: SummaryPosition.start,
          ),
          aggregates: [const _Range(qty)],
        ),
      );
      expect(cellOf(cube, 0, const _Range(qty)), 4.0);
      expect(cellOf(cube, 3, const _Range(qty)), 2.0);
      expect(cellOf(cube, 2, const _Range(qty)), 0.0);
    });
  });
}

/// max − min of a measure: a derived aggregate written by hand.
final class _Range extends DerivedAggregate<double> {
  const _Range(this.measure);
  final Measure measure;

  @override
  String get id => 'range(${measure.id})';

  @override
  String get label => 'range of ${measure.label}';

  @override
  List<Aggregate> get dependencies => [
    Aggregate.min(measure),
    Aggregate.max(measure),
  ];

  @override
  double? compute(Object? Function(Aggregate) resultOf) {
    final lo = resultOf(Aggregate.min(measure)) as double?;
    final hi = resultOf(Aggregate.max(measure)) as double?;
    return lo == null || hi == null ? null : hi - lo;
  }
}
