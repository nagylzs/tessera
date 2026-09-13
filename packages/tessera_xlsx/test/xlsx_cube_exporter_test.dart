import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:test/test.dart';
import 'package:tessera/tessera.dart';
import 'package:tessera_xlsx/tessera_xlsx.dart';

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

/// The exported sheet read back as a plain grid.
Future<List<List<Object?>>> grid(Uint8List xlsx) => XlsxDataSource.fromData(
  xlsx,
  options: const XlsxOptions(hasHeader: false, trim: false),
).rows().toList();

String sheetXml(Uint8List xlsx) => utf8.decode(
  ZipDecoder().decodeBytes(xlsx).find('xl/worksheets/sheet1.xml')!.content,
);

List<String> merges(Uint8List xlsx) =>
    RegExp(r'<mergeCell ref="([^"]+)"/>')
        .allMatches(sheetXml(xlsx))
        .map((m) => m[1]!)
        .toList();

void main() {
  late FactTable f;
  setUpAll(() async => f = await facts());

  test('a one-level cube: headers, values and blanks', () async {
    final cube = Cube(
      facts: f,
      spec: CubeSpec(
        rows: CubeAxis.of([region]),
        columns: CubeAxis.of([category]),
        aggregates: [sumQty],
      ),
    );
    final xlsx = const XlsxCubeExporter().export(cube.layout);
    expect(await grid(xlsx), [
      ['category', '(empty)', 'A', 'B', 'Total'],
      ['region', 'sum of qty', 'sum of qty', 'sum of qty', 'sum of qty'],
      ['(empty)', null, 7, null, 7],
      ['Asia', 6, null, 5, 11],
      ['Europe', null, 8, 2, 10],
      ['Total', 6, 15, 7, 28],
    ]);
    final xml = sheetXml(xlsx);
    expect(xml, contains('<dimension ref="A1:E6"/>'));
    expect(xml, contains('ySplit="2"'));
    expect(xml, contains('xSplit="1"'));
    expect(xml, contains('state="frozen"'));
    expect(xml, contains('<cols>'));
    expect(merges(xlsx), isEmpty);
    expect(XlsxWorkbook.parse(xlsx).sheets.single.name, 'Pivot');
  });

  test('expanded groups are merged in the rotated-L shape', () async {
    final cube = Cube(
      facts: f,
      spec: CubeSpec(
        rows: CubeAxis.of([region, country]),
        columns: CubeAxis.of([category]),
        aggregates: [sumQty],
      ),
    ).toggleRow(europe);
    final xlsx = const XlsxCubeExporter().export(cube.layout);
    final g = await grid(xlsx);
    // rows: ∅, Asia, Europe, ∅, Germany, Hungary, Σ under 2 header rows
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
    expect(g[6].sublist(2), [null, 1, 2, 3]); // Germany: A 1, B 2
    expect(g[4].sublist(2), [null, 8, 2, 10]); // Europe's own row = subtotal
    expect(
      merges(xlsx),
      unorderedEquals([
        'A1:B1', // corner: column-dimension title across the header columns
        'A3:B3', // collapsed ∅ spans both levels
        'A4:B4', // collapsed Asia
        'A5:A8', // Europe's label over its subtree
        'A9:B9', // summary
      ]),
    );
  });

  test('several aggregates get one sheet column each per entry', () async {
    final cube = Cube(
      facts: f,
      spec: CubeSpec(
        rows: CubeAxis.of([region]),
        columns: CubeAxis.of([category, country]),
        aggregates: [sumQty, Aggregate.count],
      ),
    ).toggleColumn(DimensionPath([const DimensionValue(category, 'B')]));
    final xlsx = const XlsxCubeExporter().export(cube.layout);
    final g = await grid(xlsx);
    // columns: ∅, A, B, Germany, Japan, Σ → 6 entries × 2 = 12 value columns
    expect(g[0].length, 13);
    expect(g[0].sublist(0, 5), ['category', '(empty)', null, 'A', null]);
    expect(g[1].sublist(0, 3), ['country', null, null]);
    expect(g[2].sublist(0, 3), ['region', 'sum of qty', 'count']);
    // B's label spans its 3 entries × 2 aggregates on level 0, its own
    // column pair is the leg on level 1; Germany/Japan sit on level 1
    expect(
      merges(xlsx),
      containsAll([
        'B1:C2',
        'D1:E2',
        'F1:K1',
        'F2:G2',
        'H2:I2',
        'J2:K2',
        'L1:M2',
      ]),
    );
    // Asia × B/Japan: sum 5, count 1 (Japan's null-category row is under ∅)
    expect(g[4].sublist(0, 1), ['Asia']);
    expect(g[4][9], 5);
    expect(g[4][10], 1);
    // only the selected aggregate, in a chosen order
    final only = const XlsxCubeExporter().export(
      cube.layout,
      aggregates: [Aggregate.count],
    );
    expect((await grid(only))[2].sublist(0, 2), ['region', 'count']);
    expect(
      () => const XlsxCubeExporter().export(
        cube.layout,
        aggregates: [Aggregate.average(qty)],
      ),
      throwsArgumentError,
    );
  });

  test('labels are localized and overridable, sheet names sanitized', () async {
    final cube = Cube(
      facts: f,
      spec: CubeSpec(rows: CubeAxis.of([region]), aggregates: [sumQty]),
    );
    final hu = XlsxCubeExporter(
      strings: TesseraStrings.forLanguage('hu')!,
      emptyGroupLabel: '–',
    );
    final xlsx = hu.export(cube.layout, sheetName: 'Sales: 2025/Q1 [draft]');
    expect(await grid(xlsx), [
      [null, 'Összesen'],
      ['region', 'qty összege'],
      ['–', 7],
      ['Asia', 11],
      ['Europe', 10],
      ['Összesen', 28],
    ]);
    expect(
      XlsxWorkbook.parse(xlsx).sheets.single.name,
      'Sales  2025 Q1  draft',
    );
    final long = const XlsxCubeExporter().export(
      cube.layout,
      sheetName: 'x' * 40,
    );
    expect(XlsxWorkbook.parse(long).sheets.single.name.length, 31);
    expect(
      XlsxWorkbook.parse(
        const XlsxCubeExporter().export(cube.layout, sheetName: '///'),
      ).sheets.single.name,
      'Pivot',
    );
  });

  test('LibreOffice opens the export and reads the same grid', () async {
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
    final dir = Directory.systemTemp.createTempSync('tessera_xlsx');
    try {
      final file = File('${dir.path}/pivot.xlsx')
        ..writeAsBytesSync(const XlsxCubeExporter().export(cube.layout));
      final result = Process.runSync('soffice', [
        '--headless',
        '--convert-to',
        'csv',
        '--outdir',
        dir.path,
        file.path,
      ]);
      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      final csv = File('${dir.path}/pivot.csv').readAsStringSync();
      final lines = const LineSplitter().convert(csv);
      expect(lines[0], 'category,,(empty),A,B,Total');
      expect(
        lines[1],
        'region,country,sum of qty,sum of qty,sum of qty,sum of qty',
      );
      // (the csv filter writes raw values, not the number format)
      expect(lines[4], 'Europe,,,8,2,10');
      expect(lines[6], ',Germany,,1,2,3');
      expect(lines[8], 'Total,,6,15,7,28');
    } finally {
      dir.deleteSync(recursive: true);
    }
  });
}
