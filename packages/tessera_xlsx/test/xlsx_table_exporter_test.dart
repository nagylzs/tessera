import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:test/test.dart';
import 'package:tessera/tessera.dart';
import 'package:tessera_xlsx/tessera_xlsx.dart';

String part(Uint8List xlsx, String name) =>
    utf8.decode(ZipDecoder().decodeBytes(xlsx).find(name)!.content);

/// The exported sheet read back as typed rows (the reader turns cells in a
/// date style into `DateTime`s).
Future<List<List<Object?>>> rowsOf(Uint8List xlsx) => XlsxDataSource.fromData(
  xlsx,
  options: const XlsxOptions(hasHeader: false, trim: false),
).rows().toList();

const columns = [
  XlsxColumn('Name'),
  XlsxColumn('Weight', format: '#,##0.00000'),
  XlsxColumn('Amount', format: '#,##0 "Ft"'),
  XlsxColumn('Day'),
  XlsxColumn('Accepted'),
];

final rows = [
  ['Kovács Anna', 0.81527, 171207.0, DateTime(2026, 3, 9), true],
  ['Nagy Béla', 1.05365, 221266.5, DateTime(2026, 3, 10, 14, 30), false],
  [null, null, null, null, null],
  ['Short row'],
];

void main() {
  test('header, typed values, empty cells and short rows', () async {
    final xlsx = const XlsxTableExporter().export(columns, rows);
    final back = await rowsOf(xlsx);
    expect(back.first, ['Name', 'Weight', 'Amount', 'Day', 'Accepted']);
    expect(back[1], [
      'Kovács Anna',
      0.81527,
      171207,
      DateTime.utc(2026, 3, 9),
      true,
    ]);
    expect(back[2][3], DateTime.utc(2026, 3, 10, 14, 30));
    expect(back.last.first, 'Short row');
    // the all-empty row writes no cells
    expect(part(xlsx, 'xl/worksheets/sheet1.xml'), isNot(contains('r="A4"')));
  });

  test('a filterable table: autofilter, frozen header, its defined name', () {
    final xlsx = const XlsxTableExporter().export(
      columns,
      rows,
      sheetName: "Kim's [report]",
    );
    final sheet = part(xlsx, 'xl/worksheets/sheet1.xml');
    expect(sheet, contains('<autoFilter ref="A1:E5"/>'));
    expect(sheet, contains('ySplit="1"'));
    expect(sheet, contains('state="frozen"'));
    // autoFilter before mergeCells and after sheetData, as the schema wants
    expect(
      sheet.indexOf('</sheetData>'),
      lessThan(sheet.indexOf('<autoFilter')),
    );
    final workbook = part(xlsx, 'xl/workbook.xml');
    expect(workbook, contains('name="Kim\'s  report"'));
    expect(
      workbook,
      contains(
        '<definedName name="_xlnm._FilterDatabase" localSheetId="0" '
        'hidden="1">\'Kim\'\'s  report\'!\$A\$1:\$E\$5</definedName>',
      ),
    );
    final off = const XlsxTableExporter(
      autoFilter: false,
      freezeHeader: false,
    ).export(columns, rows);
    expect(
      part(off, 'xl/worksheets/sheet1.xml'),
      isNot(contains('autoFilter')),
    );
    expect(part(off, 'xl/workbook.xml'), isNot(contains('definedName')));
  });

  test('number and date formats per column, no borders by default', () {
    final xlsx = const XlsxTableExporter().export(columns, rows);
    final styles = part(xlsx, 'xl/styles.xml');
    expect(styles, contains('formatCode="#,##0.00000"'));
    expect(styles, contains('formatCode="#,##0 &quot;Ft&quot;"'));
    expect(styles, contains('formatCode="yyyy-mm-dd"'));
    expect(styles, contains('formatCode="yyyy-mm-dd hh:mm"'));
    expect(styles, isNot(contains('borderId="1"')));
    final bordered = const XlsxTableExporter(borders: true)
        .export(columns, rows);
    expect(part(bordered, 'xl/styles.xml'), contains('borderId="1"'));
  });

  test('characters XML does not allow are dropped, the rest kept', () async {
    final xlsx = const XlsxTableExporter().export(
      const [XlsxColumn('Text')],
      const [
        ['a\u0001b\u000Bc\td\ne'],
      ],
    );
    final back = await rowsOf(xlsx);
    expect(back[1].first, 'abc\td\ne');
  });

  test('Excel serial dates', () {
    expect(XlsxTableExporter.excelSerialOf(DateTime(1900, 3, 1)), 61);
    expect(XlsxTableExporter.excelSerialOf(DateTime(2026, 3, 9)), 46090);
    expect(XlsxTableExporter.excelSerialOf(DateTime(2026, 3, 9, 12)), 46090.5);
  });

  test('a fact table with its labels as headers', () async {
    final facts = (await loadFacts(
      ListDataSource(
        columns: ['region', 'qty'],
        rows: const [
          ['Europe', 1],
          ['Asia', 2],
        ],
        declaredSchema: Schema([
          const ColumnSpec(
            name: 'region',
            type: ColumnType.text,
            label: 'Region',
          ),
          const ColumnSpec(
            name: 'qty',
            type: ColumnType.integer,
            label: 'Quantity',
          ),
        ]),
      ),
    )).facts;
    final xlsx = const XlsxTableExporter().exportFacts(
      facts,
      columns: ['qty', 'region'],
      formats: {'qty': '0'},
    );
    final back = await rowsOf(xlsx);
    expect(back, [
      ['Quantity', 'Region'],
      [1, 'Europe'],
      [2, 'Asia'],
    ]);
    expect(
      part(xlsx, 'xl/worksheets/sheet1.xml'),
      contains('<autoFilter ref="A1:B3"/>'),
    );
  });

  test('LibreOffice opens it and keeps the autofilter', () async {
    if (Process.runSync('which', ['soffice']).exitCode != 0) {
      markTestSkipped('soffice not installed');
      return;
    }
    final dir = Directory.systemTemp.createTempSync('tessera_xlsx_table');
    try {
      final src = Directory('${dir.path}/in')..createSync();
      final file = File('${src.path}/table.xlsx')
        ..writeAsBytesSync(const XlsxTableExporter().export(columns, rows));
      for (final target in ['csv', 'xlsx']) {
        final result = Process.runSync('soffice', [
          '--headless',
          '--convert-to',
          target,
          '--outdir',
          dir.path,
          file.path,
        ]);
        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      }
      final lines = const LineSplitter().convert(
        File('${dir.path}/table.csv').readAsStringSync(),
      );
      expect(lines.first, 'Name,Weight,Amount,Day,Accepted');
      expect(lines[1], startsWith('Kovács Anna,'));
      final resaved = File('${dir.path}/table.xlsx').readAsBytesSync();
      expect(
        part(resaved, 'xl/worksheets/sheet1.xml'),
        contains('<autoFilter ref="A1:E5"'),
      );
    } finally {
      dir.deleteSync(recursive: true);
    }
  });
}
