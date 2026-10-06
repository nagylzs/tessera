import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:test/test.dart';
import 'package:tessera/tessera.dart';
import 'package:tessera_xlsx/src/xlsx_writer.dart';
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
  ExportColumn('Name'),
  ExportColumn('Weight', numberFormat: NumberFormat(decimals: 5)),
  ExportColumn('Amount'),
  ExportColumn('Day'),
  ExportColumn('Accepted'),
];

const exporter = XlsxTableExporter(formatCodes: {'Amount': '#,##0 "Ft"'});

final table = ExportTable(columns, [
  ['Kovács Anna', 0.81527, 171207.0, DateTime(2026, 3, 9), true],
  ['Nagy Béla', 1.05365, 221266.5, DateTime(2026, 3, 10, 14, 30), false],
  [null, null, null, null, null],
  ['Short row'],
]);

void main() {
  test('header, typed values, empty cells and short rows', () async {
    final xlsx = exporter.export(table);
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
    final xlsx = exporter.export(table, sheetName: "Kim's [report]");
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
    ).export(table);
    expect(
      part(off, 'xl/worksheets/sheet1.xml'),
      isNot(contains('autoFilter')),
    );
    expect(part(off, 'xl/workbook.xml'), isNot(contains('definedName')));
  });

  test('number and date formats per column, no borders by default', () {
    final xlsx = exporter.export(table);
    final styles = part(xlsx, 'xl/styles.xml');
    expect(styles, contains('formatCode="#,##0.00000"'));
    expect(styles, contains('formatCode="#,##0 &quot;Ft&quot;"'));
    expect(styles, contains('formatCode="yyyy-mm-dd"'));
    expect(styles, contains('formatCode="yyyy-mm-dd hh:mm"'));
    expect(styles, isNot(contains('borderId="1"')));
    final bordered = const XlsxTableExporter(
      theme: TableExportTheme(borders: true),
    ).export(table);
    expect(part(bordered, 'xl/styles.xml'), contains('borderId="1"'));
  });

  test('characters XML does not allow are dropped, the rest kept', () async {
    final xlsx = const XlsxTableExporter().export(
      const ExportTable(
        [ExportColumn('Text')],
        [
          ['a\u0001b\u000Bc\td\ne'],
        ],
      ),
    );
    final back = await rowsOf(xlsx);
    expect(back[1].first, 'abc\td\ne');
  });

  test('Excel serial dates, the 1900 leap-year gap, none before 1900', () {
    expect(XlsxWriter.excelSerial(DateTime(1900)), 1);
    expect(XlsxWriter.excelSerial(DateTime(1900, 2, 28)), 59);
    expect(XlsxWriter.excelSerial(DateTime(1900, 3, 1)), 61);
    expect(XlsxWriter.excelSerial(DateTime(2026, 3, 9)), 46090);
    expect(XlsxWriter.excelSerial(DateTime(2026, 3, 9, 12)), 46090.5);
    expect(XlsxWriter.excelSerial(DateTime(1899, 12, 31)), isNull);
  });

  test('early dates read back; dates before 1900 become text', () async {
    final xlsx = const XlsxTableExporter().export(
      ExportTable(
        const [ExportColumn('Day')],
        [
          [DateTime.utc(1900, 1, 1)],
          [DateTime.utc(1900, 2, 28)],
          [DateTime.utc(1900, 3, 1)],
          [DateTime.utc(1848, 3, 15)],
        ],
      ),
    );
    final back = await rowsOf(xlsx);
    expect(back.skip(1).map((r) => r.single), [
      DateTime.utc(1900, 1, 1),
      DateTime.utc(1900, 2, 28),
      DateTime.utc(1900, 3, 1),
      '1848-03-15T00:00:00.000Z',
    ]);
  });

  test("a dateTime column keeps the time format at midnight", () {
    final xlsx = const XlsxTableExporter().export(
      ExportTable(
        const [ExportColumn('At', type: ColumnType.dateTime)],
        [
          [DateTime.utc(2026, 3, 9)],
          [DateTime.utc(2026, 3, 9, 8)],
        ],
      ),
    );
    final sheet = part(xlsx, 'xl/worksheets/sheet1.xml');
    final styles = RegExp(r'<c r="A[23]" s="(\d+)"')
        .allMatches(sheet)
        .map((m) => m[1])
        .toSet();
    expect(styles, hasLength(1));
  });

  test("Excel's limits: rows and columns throw, long text is cut", () async {
    expect(
      () => const XlsxTableExporter().export(
        ExportTable(const [
          ExportColumn('A'),
        ], Iterable.generate(XlsxTableExporter.maxRows, (_) => const [])),
      ),
      throwsArgumentError,
    );
    expect(
      () => const XlsxTableExporter().export(
        ExportTable([
          for (var c = 0; c <= XlsxTableExporter.maxColumns; c++)
            ExportColumn('c$c'),
        ], const []),
      ),
      throwsArgumentError,
    );
    // the last row that fits
    expect(
      const XlsxTableExporter().export(
        ExportTable(const [
          ExportColumn('A'),
        ], Iterable.generate(XlsxTableExporter.maxRows - 1, (_) => const [])),
      ),
      isNotEmpty,
    );
    final long = 'x' * (XlsxTableExporter.maxTextLength + 10);
    final back = await rowsOf(
      const XlsxTableExporter().export(
        ExportTable(
          const [ExportColumn('A')],
          [
            [long],
          ],
        ),
      ),
    );
    expect((back[1].single as String).length, XlsxTableExporter.maxTextLength);
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
    final xlsx = const XlsxTableExporter(formatCodes: {'qty': '0'})
        .export(ExportTable.ofFacts(facts, columns: ['qty', 'region']));
    expect(part(xlsx, 'xl/styles.xml'), contains('formatCode="0"'));
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
        ..writeAsBytesSync(exporter.export(table));
      for (final target in ['csv', 'xlsx']) {
        final result = Process.runSync('soffice', [
          // a profile of its own: another test file may run soffice now
          '-env:UserInstallation=${dir.uri.resolve('profile')}',
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
