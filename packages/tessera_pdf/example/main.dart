// Reads a CSV, builds a cube and writes it as a PDF.
//
//   dart run example/main.dart [input.csv] [output.pdf] [font directory]
//
// The font directory should hold NotoSans-Regular.ttf and
// NotoSans-Bold.ttf (default: /usr/share/fonts/noto); without them the
// built-in Helvetica is used, which has no Central European accents.
import 'dart:io';

import 'package:tessera/tessera.dart';
import 'package:tessera_pdf/tessera_pdf.dart';

Future<void> main(List<String> args) async {
  final input = args.isNotEmpty
      ? File(args[0])
      : File.fromUri(Platform.script.resolve('sales.csv'));
  final output = File(args.length > 1 ? args[1] : 'sales_pivot.pdf');
  final fontDir = Directory(
    args.length > 2 ? args[2] : '/usr/share/fonts/noto',
  );

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
  ).expandRowLevel(0).expandColumnLevel(0);

  final regular = File('${fontDir.path}/NotoSans-Regular.ttf');
  final bold = File('${fontDir.path}/NotoSans-Bold.ttf');
  final fonts = regular.existsSync()
      ? PdfFonts(
          regular: regular.readAsBytesSync(),
          bold: bold.existsSync() ? bold.readAsBytesSync() : null,
        )
      : const PdfFonts.builtIn();
  print(fonts.isBuiltIn ? 'Fonts: built-in Helvetica' : 'Fonts: Noto Sans');

  final exporter = PdfCubeExporter(
    strings: TesseraStrings.forLanguage('hu')!,
    theme: CubeExportTheme.hueLevels(levels: const HueLevels(hue: 175)),
    fonts: fonts,
    footer: const PdfPageText(left: '{date}', right: '{page} / {pages}'),
  );
  final plan = exporter.plan(cube.layout);
  print('Scale ${plan.scale.toStringAsFixed(2)}, ${plan.pageCount} pages');
  final bytes = await exporter.export(cube.layout, title: 'Sales by region');
  await output.writeAsBytes(bytes);
  print('Wrote ${output.path} (${bytes.length} bytes)');
}
