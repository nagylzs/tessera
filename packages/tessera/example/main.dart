// The engine end to end, without Flutter: read a CSV, infer its schema,
// import it, build a cube, print it, and write the cube back as CSV.
//
//   dart run example/main.dart [input.csv] [output.csv]
//
// Defaults: the sales.csv next to this file, and sales_pivot.csv in the
// current directory.
import 'dart:io';

import 'package:tessera/tessera.dart';

Future<void> main(List<String> args) async {
  final input = args.isNotEmpty
      ? File(args[0])
      : File.fromUri(Platform.script.resolve('sales.csv'));
  final output = File(args.length > 1 ? args[1] : 'sales_pivot.csv');

  // 1. A data source. fromData keeps the bytes, so the same source could
  //    also go to loadFactsInIsolate.
  final source = CsvDataSource.fromData(
    await input.readAsBytes(),
    name: input.uri.pathSegments.last,
  );
  print('Reading ${source.name} (~${await source.estimatedRowCount()} rows)');

  // 2. Infer the schema from a sample of rows and import. The report says
  //    what inference decided and what the import had to fix.
  final result = await loadFacts(source);
  final facts = result.facts;
  print('${facts.rowCount} facts, ${facts.columns.length} columns:');
  for (final c in facts.columns) {
    print('  ${c.name.padRight(12)} ${c.type.name}');
  }

  // 3. The cube: regions and countries against years and quarters, three
  //    aggregates, every region expanded.
  final cube = Cube(
    facts: facts,
    spec: CubeSpec(
      rows: CubeAxis.of([
        const ColumnDimension('region'),
        const ColumnDimension('country'),
      ]),
      columns: CubeAxis.of([
        const DatePartDimension('date', DatePart.year),
        const DatePartDimension('date', DatePart.quarter),
      ]),
      aggregates: [
        Aggregate.sum(const Measure('total')),
        Aggregate.count,
        Aggregate.average(const Measure('unit_price')),
      ],
    ),
  ).expandRowLevel(0);
  final layout = cube.layout;
  final strings = TesseraStrings.forLanguage('en')!;

  // 4. Walk the layout: one line per row entry, the first aggregate per
  //    column entry.
  final sum = cube.spec.aggregates.first;
  print(
    '\n${'region / country'.padRight(24)}'
    '${[for (final c in layout.columns.entries) _label(c, strings).padLeft(14)].join()}',
  );
  for (var i = 0; i < layout.rows.length; i++) {
    final row = layout.rows.entries[i];
    final line = StringBuffer(
      ('${'  ' * (row.depth > 0 ? row.depth - 1 : 0)}${_label(row, strings)}')
          .padRight(24),
    );
    for (var j = 0; j < layout.columns.length; j++) {
      final cell = layout.cellAt(i, j);
      final v = cell.isEmpty ? null : cell.aggregate<Object?>(sum) as num?;
      line.write((v == null ? '' : strings.formatNumber(v)).padLeft(14));
    }
    print(line);
  }

  // 5. The same grid as CSV: what `CubeView` shows, every aggregate side
  //    by side, group labels at the origin of their merged area.
  final csv = CsvCubeExporter(strings: strings).export(layout);
  await output.writeAsString(csv);
  print('\nWrote ${output.path} (${csv.length} characters)');
}

String _label(HeaderEntry e, TesseraStrings strings) => e.isSummary
    ? strings.total
    : e.value == null
    ? strings.emptyGroup
    : strings.formatValue(e.dimension, e.value);
