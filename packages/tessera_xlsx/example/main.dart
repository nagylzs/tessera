// Reads a worksheet, builds a cube and writes it back as a formatted
// workbook — the whole round trip without Flutter.
//
//   dart run example/main.dart [input.xlsx] [output.xlsx]
//
// Defaults: the sales.xlsx next to this file, and sales_pivot.xlsx in the
// current directory.
import 'dart:io';

import 'package:tessera/tessera.dart';
import 'package:tessera_xlsx/tessera_xlsx.dart';

Future<void> main(List<String> args) async {
  final input = args.isNotEmpty
      ? File(args[0])
      : File.fromUri(Platform.script.resolve('sales.xlsx'));
  final output = File(args.length > 1 ? args[1] : 'sales_pivot.xlsx');

  // 1. A worksheet as a data source. fromData keeps the bytes, so the same
  //    source could also go to loadFactsInIsolate.
  final source = XlsxDataSource.fromData(
    await input.readAsBytes(),
    name: input.uri.pathSegments.last,
  );
  print('Reading ${source.name} (~${await source.estimatedRowCount()} rows)');

  // 2. Infer the schema from the typed cells and import.
  final result = await loadFacts(source);
  final facts = result.facts;
  print('${facts.rowCount} facts, ${facts.columns.length} columns:');
  for (final c in facts.columns) {
    print('  ${c.name.padRight(12)} ${c.type.name}');
  }

  // 3. The same cube as the Flutter example's "Simple pivot": regions and
  //    countries against years and quarters, three aggregates — with
  //    every region expanded.
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
  print(
    'Cube: ${layout.rows.length} rows × ${layout.columns.length} columns, '
    'grand total ${layout.cellAt(layout.rows.length - 1, layout.columns.length - 1).aggregate(cube.spec.aggregates.first)}',
  );

  // 4. Write it as a worksheet: merged group headers, one column per
  //    aggregate, level shading, frozen headers, English labels.
  //    The theme is pure Dart: a brand colour, fonts, fills as ARGB ints.
  final bytes = XlsxCubeExporter(
    strings: TesseraStrings.forLanguage('en')!,
    theme: XlsxCubeTheme.brand(primary: 0xFF00695C, fontFamily: 'Calibri'),
  ).export(layout, sheetName: 'Sales by region');
  await output.writeAsBytes(bytes);
  print('Wrote ${output.path} (${bytes.length} bytes)');
}
