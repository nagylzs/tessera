// Times the pipeline on a CSV file: `dart run tool/bench.dart path/to/big.csv`
// (generate one with `dart run tool/gen_sales_csv.dart --rows 2000000 --out big.csv`).
// ignore_for_file: avoid_print

import 'dart:io';

import 'package:tessera/tessera.dart';

Future<void> main(List<String> args) async {
  final path = args.first;
  final file = File(path);
  print('file: ${(file.lengthSync() / 1e6).toStringAsFixed(1)} MB');
  final source = CsvDataSource.fromBytes(file.openRead, name: 'big');

  var sw = Stopwatch()..start();
  final n = await source.rows().length;
  print('parse only:  ${sw.elapsedMilliseconds} ms  ($n rows)');

  sw = Stopwatch()..start();
  final schema = await inferSchema(source);
  print('infer:       ${sw.elapsedMilliseconds} ms');

  sw = Stopwatch()..start();
  final result = await const FactTableImporter().import(source, schema);
  print(
    'import:      ${sw.elapsedMilliseconds} ms  (${result.facts.rowCount} rows)',
  );

  final facts = result.facts;
  const region = ColumnDimension('region');
  const country = ColumnDimension('country');
  const year = DatePartDimension('date', DatePart.year);
  const quarter = DatePartDimension('date', DatePart.quarter);
  final spec = CubeSpec(
    rows: CubeAxis.of([region, country]),
    columns: CubeAxis.of([year, quarter]),
    aggregates: [Aggregate.sum(const Measure('total')), Aggregate.count],
  );
  sw = Stopwatch()..start();
  var cube = Cube(facts: facts, spec: spec);
  cube.layout;
  print(
    'first cube:  ${sw.elapsedMilliseconds} ms  (dimension codes + layout)',
  );

  sw = Stopwatch()..start();
  cube = cube.expandRowsToDepth(2).expandColumnsToDepth(2);
  cube.layout;
  print(
    'expand all:  ${sw.elapsedMilliseconds} ms  (${cube.layout.rows.length} x ${cube.layout.columns.length})',
  );

  sw = Stopwatch()..start();
  cube = cube.toggleRow(
    DimensionPath([const DimensionValue(region, 'Europe')]),
  );
  cube.layout;
  print('toggle:      ${sw.elapsedMilliseconds} ms');
  print('rss: ${(ProcessInfo.currentRss / 1e6).toStringAsFixed(0)} MB');

  // Expressions: one pass per fact each, results cached afterwards.
  sw = Stopwatch()..start();
  Cube(
    facts: facts,
    spec: spec.copyWith(
      filter: () => ExpressionFilter(
        'total > 100 and region = "Europe" and year(date) = 2024',
      ),
    ),
  ).layout;
  print('expr filter: ${sw.elapsedMilliseconds} ms  (filter scan + cube)');

  sw = Stopwatch()..start();
  final net = Measure.expression(
    'quantity * unit_price * (1 - coalesce(discount, 0))',
    label: 'net',
  );
  Cube(
    facts: facts,
    spec: spec.copyWith(aggregates: [Aggregate.sum(net)]),
  ).layout;
  print('expr measure: ${sw.elapsedMilliseconds} ms  (materialize + cube)');

  sw = Stopwatch()..start();
  Cube(
    facts: facts,
    spec: spec.copyWith(
      rows: CubeAxis.of([
        ExpressionDimension('if(total > 100, "big", "small")', label: 'size'),
        country,
      ]),
    ),
  ).layout;
  print('expr dimension: ${sw.elapsedMilliseconds} ms  (materialize + cube)');

  sw = Stopwatch()..start();
  Cube(
    facts: facts,
    spec: spec.copyWith(
      aggregates: [Aggregate.expression('sum(total) / count', label: 'avg')],
    ),
  ).layout;
  print('expr aggregate: ${sw.elapsedMilliseconds} ms  (cube)');
}
