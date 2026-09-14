import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:tessera/tessera.dart';

const x = Measure('x');
const g = ColumnDimension('g');

Future<FactTable> facts(List<List<Object?>> rows) async {
  final source = ListDataSource(
    columns: ['g', 'x'],
    rows: rows,
    declaredSchema: Schema([
      const ColumnSpec(name: 'g', type: ColumnType.text),
      const ColumnSpec(name: 'x', type: ColumnType.number),
    ]),
  );
  return (await loadFacts(source)).facts;
}

/// Two-pass reference values.
(double mean, double m2) reference(Iterable<double> values) {
  final list = values.toList();
  final mean = list.fold(0.0, (a, b) => a + b) / list.length;
  final m2 = list.fold(0.0, (a, b) => a + (b - mean) * (b - mean));
  return (mean, m2);
}

void main() {
  test('results against a two-pass reference, with nulls', () async {
    final rows = <List<Object?>>[
      ['a', 2.0],
      ['a', 4.0],
      ['a', null],
      ['a', 4.0],
      ['b', 4.0],
      ['b', 5.0],
      ['b', 5.0],
      ['b', 7.0],
      ['b', 9.0],
    ];
    final f = await facts(rows);
    final values = [
      for (final r in rows)
        if (r[1] != null) r[1] as double,
    ];
    final (_, m2) = reference(values);
    final n = values.length;
    final cube = Cube(
      facts: f,
      spec: CubeSpec(
        rows: const CubeAxis(dimensions: [AxisDimension(g)]),
        aggregates: [
          Aggregate.stdDev(x),
          Aggregate.stdDevPopulation(x),
          Aggregate.variance(x),
          Aggregate.variancePopulation(x),
        ],
      ),
    );
    // summary is the last row
    final total = cube.layout.cellAt(2, 0);
    expect(
      total.aggregate(Aggregate.variance(x)),
      closeTo(m2 / (n - 1), 1e-12),
    );
    expect(
      total.aggregate(Aggregate.variancePopulation(x)),
      closeTo(m2 / n, 1e-12),
    );
    expect(
      total.aggregate(Aggregate.stdDev(x)),
      closeTo(math.sqrt(m2 / (n - 1)), 1e-12),
    );
    expect(
      total.aggregate(Aggregate.stdDevPopulation(x)),
      closeTo(math.sqrt(m2 / n), 1e-12),
    );
    // the textbook values: population variance of 2,4,4,4,5,5,7,9 is 4
    expect(total.aggregate(Aggregate.variancePopulation(x)), closeTo(4, 1e-12));
    expect(total.aggregate(Aggregate.stdDevPopulation(x)), closeTo(2, 1e-12));
    final a = cube.layout.cellAt(0, 0);
    expect(a.aggregate(Aggregate.variancePopulation(x)), closeTo(8 / 9, 1e-12));
    expect(a.aggregate(Aggregate.variance(x)), closeTo(4 / 3, 1e-12));
  });

  test('merging children equals a direct computation', () async {
    final rnd = math.Random(7);
    final rows = <List<Object?>>[
      for (var i = 0; i < 2000; i++)
        ['g${rnd.nextInt(20)}', 1e9 + rnd.nextDouble() * 10],
    ];
    final f = await facts(rows);
    final values = [for (final r in rows) r[1] as double];
    final (_, m2) = reference(values);
    final expanded = Cube(
      facts: f,
      spec: CubeSpec(
        rows: const CubeAxis(dimensions: [AxisDimension(g)]),
        aggregates: [Aggregate.variance(x)],
      ),
    );
    final flat = Cube(
      facts: f,
      spec: CubeSpec(aggregates: [Aggregate.variance(x)]),
    );
    final merged = expanded.layout.cellAt(expanded.layout.rows.length - 1, 0);
    final direct = flat.layout.cellAt(0, 0);
    final want = m2 / (values.length - 1);
    // large mean (1e9), small spread: the naive E[x²]−E[x]² would be off
    expect(direct.aggregate(Aggregate.variance(x)), closeTo(want, want * 1e-6));
    expect(merged.aggregate(Aggregate.variance(x)), closeTo(want, want * 1e-6));
  });

  test('too few values give null', () async {
    final f = await facts([
      ['a', 3.0],
      ['b', null],
    ]);
    final cube = Cube(
      facts: f,
      spec: CubeSpec(
        rows: const CubeAxis(dimensions: [AxisDimension(g)]),
        aggregates: [
          Aggregate.stdDev(x),
          Aggregate.stdDevPopulation(x),
          Aggregate.variance(x),
          Aggregate.variancePopulation(x),
        ],
      ),
    );
    final a = cube.layout.cellAt(0, 0), b = cube.layout.cellAt(1, 0);
    expect(a.aggregate(Aggregate.stdDev(x)), isNull);
    expect(a.aggregate(Aggregate.variance(x)), isNull);
    expect(a.aggregate(Aggregate.stdDevPopulation(x)), 0.0);
    expect(a.aggregate(Aggregate.variancePopulation(x)), 0.0);
    expect(b.aggregates.values, [null, null, null, null]);
  });

  test('ids, labels, kinds and cell formulas', () async {
    expect(Aggregate.stdDev(x).id, 'stdev(x)');
    expect(Aggregate.stdDevPopulation(x).id, 'stdevp(x)');
    expect(Aggregate.variance(x).id, 'var(x)');
    expect(Aggregate.variancePopulation(x).id, 'varp(x)');
    final f = await facts([
      ['a', 1.0],
    ]);
    const en = TesseraStringsEn();
    expect(en.aggregateLabel(Aggregate.stdDev(x), f), 'std dev of x');
    expect(
      en.aggregateLabel(Aggregate.variancePopulation(x), f),
      'population variance of x',
    );
    expect(en.aggregateKindLabel(AggregateKind.stdDev), 'Standard deviation');
    for (final k in [
      AggregateKind.stdDev,
      AggregateKind.stdDevPopulation,
      AggregateKind.variance,
      AggregateKind.variancePopulation,
    ]) {
      expect(k.needsMeasure, isTrue);
      expect(k.needsDimension, isFalse);
    }
    expect(AggregateKind.variance.build(measure: x), Aggregate.variance(x));
    expect(
      Aggregate.expression('stdev(x) / avg(x) + var(x) + stdevp(x) + varp(x)')
          .dependencies,
      [
        Aggregate.stdDev(x),
        Aggregate.average(x),
        Aggregate.variance(x),
        Aggregate.stdDevPopulation(x),
        Aggregate.variancePopulation(x),
      ],
    );
    final cv = Aggregate.expression('stdevp(x) / avg(x)');
    final data = await facts([
      ['a', 2.0],
      ['a', 4.0],
      ['a', 4.0],
      ['a', 4.0],
      ['a', 5.0],
      ['a', 5.0],
      ['a', 7.0],
      ['a', 9.0],
    ]);
    final cube = Cube(
      facts: data,
      spec: CubeSpec(aggregates: [cv]),
    );
    expect(cube.layout.cellAt(0, 0).aggregate(cv), closeTo(2 / 5, 1e-12));
  });
}
