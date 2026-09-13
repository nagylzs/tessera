// Reads a sheet, builds a cube and writes it back as a formatted
// OpenDocument spreadsheet — the whole round trip without Flutter.
//
//   dart run example/main.dart [input.ods] [output.ods]
//
// Defaults: the sales.ods next to this file, and sales_pivot.ods in the
// current directory.
import 'dart:io';

import 'package:tessera/tessera.dart';
import 'package:tessera_ods/tessera_ods.dart';

Future<void> main(List<String> args) async {
  final input = args.isNotEmpty
      ? File(args[0])
      : File.fromUri(Platform.script.resolve('sales.ods'));
  final output = File(args.length > 1 ? args[1] : 'sales_pivot.ods');

  final source = OdsDataSource.fromData(
    await input.readAsBytes(),
    name: input.uri.pathSegments.last,
  );
  print('Reading ${source.name} (~${await source.estimatedRowCount()} rows)');
  final result = await loadFacts(source);
  final facts = result.facts;
  print('${facts.rowCount} facts, ${facts.columns.length} columns:');
  for (final c in facts.columns) {
    print('  ${c.name.padRight(12)} ${c.type.name}');
  }

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
  print('Cube: ${layout.rows.length} rows × ${layout.columns.length} columns');

  final bytes = OdsCubeExporter(
    strings: TesseraStrings.forLanguage('en')!,
    theme: CubeExportTheme.brand(
      primary: 0xFF00695C,
      fontFamily: 'Liberation Sans',
    ),
  ).export(layout, sheetName: 'Sales by region');
  await output.writeAsBytes(bytes);
  print('Wrote ${output.path} (${bytes.length} bytes)');
}
