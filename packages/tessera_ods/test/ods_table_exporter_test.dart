import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:test/test.dart';
import 'package:tessera/tessera.dart';
import 'package:tessera_ods/tessera_ods.dart';
import 'package:xml/xml.dart';

/// The exported sheet read back as typed rows.
Future<List<List<Object?>>> rowsOf(Uint8List ods) => OdsDataSource.fromData(
  ods,
  options: const OdsOptions(hasHeader: false, trim: false),
).rows().toList();

String part(Uint8List ods, String name) =>
    utf8.decode(ZipDecoder().decodeBytes(ods).find(name)!.content);

const columns = [
  ExportColumn('Name'),
  ExportColumn('Weight', numberFormat: NumberFormat(decimals: 5)),
  ExportColumn('Amount'),
  ExportColumn('Day'),
  ExportColumn('Accepted'),
];

final table = ExportTable(columns, [
  ['Kovács Anna', 0.81527, 171207.0, DateTime.utc(2026, 3, 9), true],
  ['Nagy Béla', 1.05365, 221266.5, DateTime.utc(2026, 3, 10, 14, 30), false],
  [null, null, null, null, null],
  ['Short row'],
]);

void main() {
  test('header, typed values, empty cells and short rows', () async {
    final ods = const OdsTableExporter().export(table);
    final back = await rowsOf(ods);
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
    // well-formed, the mimetype first and stored
    XmlDocument.parse(part(ods, 'content.xml'));
    final first = ZipDecoder().decodeBytes(ods).files.first;
    expect(first.name, 'mimetype');
  });

  test('a filterable table: database range, frozen, repeated header', () {
    final ods = const OdsTableExporter().export(
      table,
      sheetName: "Kim's report",
    );
    final content = part(ods, 'content.xml');
    expect(
      content,
      contains(
        'table:target-range-address="\'Kim\'\'s report\'.A1:'
        '\'Kim\'\'s report\'.E5" table:display-filter-buttons="true"',
      ),
    );
    expect(content, contains('<table:table-header-rows>'));
    final settings = part(ods, 'settings.xml');
    expect(
      settings,
      contains(
        '<config:config-item config:name="VerticalSplitPosition" '
        'config:type="int">1</config:config-item>',
      ),
    );
    final off = const OdsTableExporter(
      autoFilter: false,
      freezeHeader: false,
    ).export(table);
    expect(part(off, 'content.xml'), isNot(contains('database-range')));
    expect(ZipDecoder().decodeBytes(off).find('settings.xml'), isNull);
  });

  test('number and date styles, borders from the theme', () {
    final ods = const OdsTableExporter().export(table);
    final content = part(ods, 'content.xml');
    expect(content, contains('number:decimal-places="5"'));
    expect(content, contains('<number:date-style style:name="D0">'));
    expect(content, contains('<number:hours number:style="long"/>'));
    expect(content, isNot(contains('fo:border')));
    final bordered = const OdsTableExporter(
      theme: TableExportTheme(borders: true, headerFill: null),
    ).export(table);
    final styled = part(bordered, 'content.xml');
    expect(styled, contains('fo:border="0.5pt solid #bfbfbf"'));
    expect(styled, isNot(contains('fo:background-color')));
  });

  test(
    'line breaks, tabs and spaces survive; illegal characters do not',
    () async {
      const texts = [
        'two\nlines',
        '\tindented',
        '  leading',
        'trailing  ',
        'a  b   c',
        'x\u0001y',
      ];
      final ods = const OdsTableExporter().export(
        ExportTable(
          const [ExportColumn('Text')],
          [
            for (final t in texts) [t],
          ],
        ),
      );
      final back = await rowsOf(ods);
      expect(back.skip(1).map((r) => r.single), [...texts.take(5), 'xy']);
    },
  );

  test('a dateTime column keeps its time at midnight', () async {
    final ods = const OdsTableExporter().export(
      ExportTable(
        const [ExportColumn('At', type: ColumnType.dateTime)],
        [
          [DateTime.utc(2026, 3, 9)],
          [DateTime.utc(1848, 3, 15, 9, 5, 7, 250)],
        ],
      ),
    );
    final content = part(ods, 'content.xml');
    expect(content, contains('office:date-value="2026-03-09T00:00:00"'));
    expect(content, contains('office:date-value="1848-03-15T09:05:07.250"'));
    final back = await rowsOf(ods);
    expect(back[2].single, DateTime.utc(1848, 3, 15, 9, 5, 7, 250));
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
    final ods = const OdsTableExporter().export(
      ExportTable.ofFacts(facts, columns: ['qty', 'region']),
    );
    expect(await rowsOf(ods), [
      ['Quantity', 'Region'],
      [1, 'Europe'],
      [2, 'Asia'],
    ]);
  });

  test('sales.ods round trip: the facts come back', () async {
    final source = OdsDataSource.fromData(
      File('test/data/sales.ods').readAsBytesSync(),
    );
    final facts = (await loadFacts(source)).facts;
    final ods = const OdsTableExporter().export(
      ExportTable.ofFacts(facts, useLabels: false),
    );
    final back = (await loadFacts(OdsDataSource.fromData(ods))).facts;
    expect(back.rowCount, facts.rowCount);
    for (final c in facts.columns) {
      expect(back.column(c.name).type, c.type, reason: c.name);
      for (var r = 0; r < facts.rowCount; r++) {
        expect(
          back.valueAt(r, c.name),
          facts.valueAt(r, c.name),
          reason: '${c.name}[$r]',
        );
      }
    }
  });

  test('LibreOffice opens it and keeps the autofilter', () async {
    if (Process.runSync('which', ['soffice']).exitCode != 0) {
      markTestSkipped('soffice not installed');
      return;
    }
    final dir = Directory.systemTemp.createTempSync('tessera_ods_table');
    try {
      final src = Directory('${dir.path}/in')..createSync();
      final file = File('${src.path}/table.ods')
        ..writeAsBytesSync(const OdsTableExporter().export(table));
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
      final sheet = utf8.decode(
        ZipDecoder()
            .decodeBytes(File('${dir.path}/table.xlsx').readAsBytesSync())
            .find('xl/worksheets/sheet1.xml')!
            .content,
      );
      expect(sheet, contains('<autoFilter ref="A1:E5"'));
    } finally {
      dir.deleteSync(recursive: true);
    }
  });
}
