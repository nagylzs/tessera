// Reads a CSV, builds a cube and writes it as an HTML page.
//
//   dart run example/main.dart [input.csv] [output.html]
import 'dart:io';

import 'package:tessera/tessera.dart';
import 'package:tessera_html/tessera_html.dart';

Future<void> main(List<String> args) async {
  final input = args.isNotEmpty
      ? File(args[0])
      : File.fromUri(Platform.script.resolve('sales.csv'));
  final output = File(args.length > 1 ? args[1] : 'sales_pivot.html');

  final source = CsvDataSource.fromData(
    await input.readAsBytes(),
    name: input.uri.pathSegments.last,
  );
  final facts = (await loadFacts(source)).facts;
  print('${facts.rowCount} facts, ${facts.columns.length} columns');

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

  final html = HtmlCubeExporter(
    strings: TesseraStrings.forLanguage('en')!,
    theme: CubeExportTheme.brand(primary: 0xFF00695C, fontFamily: 'Segoe UI'),
  ).export(cube.layout, title: 'Sales by region');
  await output.writeAsString(html);
  print('Wrote ${output.path} (${html.length} characters)');
}
