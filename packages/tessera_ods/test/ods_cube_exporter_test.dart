import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:test/test.dart';
import 'package:tessera/tessera.dart';
import 'package:tessera_ods/tessera_ods.dart';

const region = ColumnDimension('region');
const country = ColumnDimension('country');
const category = ColumnDimension('category');
const qty = Measure('qty');
final sumQty = Aggregate.sum(qty);

Future<FactTable> facts() async {
  final source = ListDataSource(
    columns: ['region', 'country', 'category', 'qty'],
    rows: const [
      ['Europe', 'Germany', 'A', 1],
      ['Europe', 'Germany', 'B', 2],
      ['Europe', 'Hungary', 'A', 3],
      ['Europe', null, 'A', 4],
      ['Asia', 'Japan', 'B', 5],
      ['Asia', 'Japan', null, 6],
      [null, 'Iceland', 'A', 7],
      [null, null, null, null],
    ],
    declaredSchema: Schema([
      const ColumnSpec(name: 'region', type: ColumnType.text),
      const ColumnSpec(name: 'country', type: ColumnType.text),
      const ColumnSpec(name: 'category', type: ColumnType.text),
      const ColumnSpec(name: 'qty', type: ColumnType.integer),
    ]),
  );
  return (await loadFacts(source)).facts;
}

final europe = DimensionPath([const DimensionValue(region, 'Europe')]);

/// The exported sheet read back as a plain grid; covered (merged) cells
/// are empty.
Future<List<List<Object?>>> grid(Uint8List ods) => OdsDataSource.fromData(
  ods,
  options: const OdsOptions(hasHeader: false, trim: false),
).rows().toList();

String part(Uint8List ods, String name) =>
    utf8.decode(ZipDecoder().decodeBytes(ods).find(name)!.content);

void main() {
  late FactTable f;
  setUpAll(() async => f = await facts());

  test('a one-level cube: headers, values, blanks, package parts', () async {
    final cube = Cube(
      facts: f,
      spec: CubeSpec(
        rows: CubeAxis.of([region]),
        columns: CubeAxis.of([category]),
        aggregates: [sumQty],
      ),
    );
    final ods = const OdsCubeExporter().export(cube.layout);
    expect(await grid(ods), [
      ['category', '(empty)', 'A', 'B', 'Total'],
      ['region', 'sum of qty', 'sum of qty', 'sum of qty', 'sum of qty'],
      ['(empty)', null, 7, null, 7],
      ['Asia', 6, null, 5, 11],
      ['Europe', null, 8, 2, 10],
      ['Total', 6, 15, 7, 28],
    ]);
    final zip = ZipDecoder().decodeBytes(ods);
    expect(zip.files.first.name, 'mimetype');
    expect(zip.files.first.compression, CompressionType.none);
    expect(part(ods, 'settings.xml'), contains('VerticalSplitPosition'));
    expect(
      part(ods, 'settings.xml'),
      contains('config:name="HorizontalSplitPosition" config:type="int">1<'),
    );
    expect(part(ods, 'content.xml'), contains('number:grouping="true"'));
    expect(part(ods, 'content.xml'), contains('fo:font-weight="bold"'));
  });

  test('expanded groups are merged in the rotated-L shape', () async {
    final cube = Cube(
      facts: f,
      spec: CubeSpec(
        rows: CubeAxis.of([region, country]),
        columns: CubeAxis.of([category]),
        aggregates: [sumQty, Aggregate.count],
      ),
    ).toggleRow(europe);
    final ods = const OdsCubeExporter().export(cube.layout);
    final g = await grid(ods);
    expect(g.map((r) => r.take(2).toList()), [
      ['category', null],
      ['region', 'country'],
      ['(empty)', null],
      ['Asia', null],
      ['Europe', null],
      [null, '(empty)'],
      [null, 'Germany'],
      [null, 'Hungary'],
      ['Total', null],
    ]);
    expect(g[6].sublist(2, 6), [null, null, 1, 1]); // Germany × ∅, A
    final xml = part(ods, 'content.xml');
    expect(
      xml,
      contains(
        'table:number-columns-spanned="1" table:number-rows-spanned="4"',
      ),
    ); // Europe over its subtree
    expect(
      xml,
      contains(
        'table:number-columns-spanned="2" table:number-rows-spanned="1"',
      ),
    ); // a column entry over its two aggregates
    expect(xml, contains('<table:covered-table-cell'));
  });

  test('theme and localized labels', () async {
    final cube = Cube(
      facts: f,
      spec: CubeSpec(rows: CubeAxis.of([region]), aggregates: [sumQty]),
    );
    final ods = OdsCubeExporter(
      strings: TesseraStrings.forLanguage('hu')!,
      theme:
          CubeExportTheme.brand(
            primary: 0xFF1A73E8,
            fontFamily: 'Liberation Sans',
          ).copyWith(
            numberFormat: const NumberFormat(decimals: 0, grouping: false),
          ),
      freezeHeaders: false,
    ).export(cube.layout, sheetName: 'Riport');
    expect((await grid(ods)).last, ['Összesen', 28]);
    final xml = part(ods, 'content.xml');
    expect(xml, contains('fo:background-color="#1a73e8"'));
    expect(xml, contains('style:font-name="Liberation Sans"'));
    expect(xml, contains('fo:color="#ffffff"'));
    expect(xml, contains('number:decimal-places="0"'));
    expect(xml, isNot(contains('number:grouping')));
    expect(xml, contains('table:name="Riport"'));
    expect(ZipDecoder().decodeBytes(ods).find('settings.xml'), isNull);
  });

  test('whole numbers without decimals, as the grid shows them', () {
    // counts are ints; the averages 7.0 and 4.0 are whole doubles, while
    // 5.5 and 2.5 are not
    final cube = Cube(
      facts: f,
      spec: CubeSpec(
        rows: CubeAxis.of([region]),
        aggregates: [Aggregate.count, Aggregate.average(qty)],
      ),
    );
    final xml = part(
      const OdsCubeExporter().export(cube.layout),
      'content.xml',
    );
    final decimalsOf = {
      for (final m in RegExp(
        r'<number:number-style style:name="(N\d)"><number:number '
        r'number:decimal-places="(\d+)"',
      ).allMatches(xml))
        m[1]!: int.parse(m[2]!),
    };
    expect(decimalsOf, {'N1': 2, 'N0': 0});
    final numberStyleOf = {
      for (final m in RegExp(
        r'style:name="(ce\d+)" style:family="table-cell" '
        r'style:data-style-name="(N\d)"',
      ).allMatches(xml))
        m[1]!: m[2]!,
    };
    final cells = RegExp(
      r'table:style-name="(ce\d+)" office:value-type="float" '
      r'office:value="([^"]+)"><text:p>([^<]*)</text:p>',
    ).allMatches(xml).toList();
    expect(cells, hasLength(8));
    for (final m in cells) {
      final value = num.parse(m[2]!);
      final whole = value == value.truncate();
      expect(decimalsOf[numberStyleOf[m[1]!]], whole ? 0 : 2, reason: m[2]);
      expect(m[3], whole ? '${value.toInt()}' : value.toStringAsFixed(2));
    }

    // a theme without decimals needs no second number style
    final plain = part(
      const OdsCubeExporter(
        theme: CubeExportTheme(numberFormat: NumberFormat(decimals: 0)),
      ).export(cube.layout),
      'content.xml',
    );
    expect(plain, isNot(contains('style:name="N0"')));
  });

  test('LibreOffice shows the numbers as the grid does', () async {
    if (Process.runSync('which', ['soffice']).exitCode != 0) {
      markTestSkipped('soffice not installed');
      return;
    }
    final cube = Cube(
      facts: f,
      spec: CubeSpec(
        rows: CubeAxis.of([region]),
        aggregates: [Aggregate.count, Aggregate.average(qty)],
      ),
    );
    final dir = Directory.systemTemp.createTempSync('tessera_ods');
    try {
      final file = File('${dir.path}/pivot.ods')
        ..writeAsBytesSync(const OdsCubeExporter().export(cube.layout));
      // tab-separated, UTF-8, cells "as shown" (the 9th token)
      final result = Process.runSync('soffice', [
        '--headless',
        '--convert-to',
        'csv:Text - txt - csv (StarCalc):9,34,76,1,,1033,false,true,true',
        '--outdir',
        dir.path,
        file.path,
      ]);
      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      final lines = const LineSplitter().convert(
        File('${dir.path}/pivot.csv').readAsStringSync(),
      );
      // the decimal mark is LibreOffice's locale's
      expect(
        lines.skip(2).join('\n'),
        matches(
          RegExp(
            '^\\(empty\\)\t2\t7\nAsia\t2\t5[.,]50\n'
            'Europe\t4\t2[.,]50\nTotal\t8\t4\$',
          ),
        ),
      );
    } finally {
      dir.deleteSync(recursive: true);
    }
  });

  test('LibreOffice opens the export: values and merges', () async {
    if (Process.runSync('which', ['soffice']).exitCode != 0) {
      markTestSkipped('soffice not installed');
      return;
    }
    final cube = Cube(
      facts: f,
      spec: CubeSpec(
        rows: CubeAxis.of([region, country]),
        columns: CubeAxis.of([category]),
        aggregates: [sumQty],
      ),
    ).toggleRow(europe);
    final dir = Directory.systemTemp.createTempSync('tessera_ods');
    try {
      final file = File('${dir.path}/pivot.ods')
        ..writeAsBytesSync(const OdsCubeExporter().export(cube.layout));
      for (final format in ['csv', 'xlsx']) {
        final r = Process.runSync('soffice', [
          '--headless',
          '--convert-to',
          format,
          '--outdir',
          dir.path,
          file.path,
        ]);
        expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
      }
      final lines = const LineSplitter().convert(
        File('${dir.path}/pivot.csv').readAsStringSync(),
      );
      expect(lines[0], 'category,,(empty),A,B,Total');
      expect(lines[4], 'Europe,,,8,2,10');
      expect(lines[6], ',Germany,,1,2,3');
      // the xlsx LibreOffice writes from it keeps the merges and the pane
      final sheet = utf8.decode(
        ZipDecoder()
            .decodeBytes(File('${dir.path}/pivot.xlsx').readAsBytesSync())
            .find('xl/worksheets/sheet1.xml')!
            .content,
      );
      expect(sheet, contains('<mergeCell ref="A5:A8"/>'));
      // frozen panes cannot be checked this way: a headless conversion has
      // no view, so LibreOffice drops view settings in both directions
    } finally {
      dir.deleteSync(recursive: true);
    }
  });
}
