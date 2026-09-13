import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:test/test.dart';
import 'package:tessera/tessera.dart';
import 'package:tessera_xlsx/tessera_xlsx.dart';

Future<List<List<Object?>>> rowsOf(DataSource s) => s.rows().toList();

/// A minimal workbook: [sheets] maps sheet names to the XML inside
/// `<sheetData>`; cells reference [sharedStrings] by index.
Uint8List buildXlsx({
  required Map<String, String> sheets,
  List<String> sharedStrings = const [],
  String numFmts = '',
  String cellXfs = '<xf numFmtId="0"/>',
  bool date1904 = false,
}) {
  final archive = Archive();
  void add(String path, String xml) =>
      archive.add(ArchiveFile.string(path, xml));
  final names = sheets.keys.toList();
  add(
    'xl/workbook.xml',
    '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<workbookPr date1904="${date1904 ? 1 : 0}"/><sheets>'
        '${[for (var i = 0; i < names.length; i++) '<sheet name="${names[i]}" sheetId="${i + 1}" r:id="rId${i + 1}"/>'].join()}'
        '</sheets></workbook>',
  );
  add(
    'xl/_rels/workbook.xml.rels',
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '${[for (var i = 0; i < names.length; i++) '<Relationship Id="rId${i + 1}" Type="w" Target="worksheets/sheet${i + 1}.xml"/>'].join()}'
        '</Relationships>',
  );
  add(
    'xl/sharedStrings.xml',
    '<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '${[for (final s in sharedStrings) '<si><t>$s</t></si>'].join()}</sst>',
  );
  add(
    'xl/styles.xml',
    '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '<numFmts>$numFmts</numFmts><cellXfs>$cellXfs</cellXfs></styleSheet>',
  );
  for (var i = 0; i < names.length; i++) {
    add(
      'xl/worksheets/sheet${i + 1}.xml',
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
          '${sheets[names[i]]}</worksheet>',
    );
  }
  return ZipEncoder().encodeBytes(archive);
}

void main() {
  group('XlsxDataSource on a LibreOffice workbook', () {
    late Uint8List bytes;
    setUpAll(() => bytes = File('test/data/sales.xlsx').readAsBytesSync());

    test('imports the same facts as sales.csv', () async {
      final xlsx = XlsxDataSource.fromData(bytes, name: 'sales.xlsx');
      final csv = CsvDataSource.fromData(
        File('../tessera/test/data/sales.csv').readAsBytesSync(),
        name: 'sales.csv',
      );
      expect(await xlsx.columnNames(), await csv.columnNames());
      expect(await xlsx.estimatedRowCount(), 1000);
      final a = (await loadFacts(xlsx)).facts;
      final b = (await loadFacts(csv)).facts;
      expect(a.rowCount, b.rowCount);
      for (final c in b.columns) {
        expect(a.column(c.name).type, c.type, reason: c.name);
        for (var r = 0; r < b.rowCount; r++) {
          expect(
            a.valueAt(r, c.name),
            b.valueAt(r, c.name),
            reason: '${c.name} row $r',
          );
        }
      }
      expect(a.column('date').type, ColumnType.date);
      expect(a.valueAt(0, 'date'), DateTime.utc(2025, 5, 26));
      expect(a.column('quantity').type, ColumnType.integer);
    });

    test('is sendable to the import isolate', () async {
      final result = await loadFactsInIsolate(
        XlsxDataSource.fromData(bytes, name: 'sales.xlsx'),
      );
      expect(result.facts.rowCount, 1000);
    });
  });

  group('XlsxDataSource on hand-built workbooks', () {
    test('typed cells: shared, inline and formula strings, numbers, '
        'booleans, errors, gaps', () async {
      final source = XlsxDataSource.fromData(
        buildXlsx(
          sharedStrings: ['name', 'n', 'ok', ' padded ', 'x'],
          sheets: {
            'Data':
                '<dimension ref="A1:D3"/><sheetData>'
                '<row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c>'
                '<c r="C1" t="s"><v>2</v></c><c r="D1" t="inlineStr"><is><t>note</t></is></c></row>'
                '<row r="2"><c r="A2" t="s"><v>3</v></c><c r="B2"><v>20</v></c>'
                '<c r="C2" t="b"><v>1</v></c><c r="D2" t="str"><f>A2&amp;"!"</f><v>padded!</v></c></row>'
                '<row r="3"><c r="A3" t="s"><v>4</v></c><c r="B3"><v>6.5</v></c>'
                '<c r="D3" t="e"><v>#DIV/0!</v></c></row>'
                '<row r="5"><c r="B5"><f>B2*2</f><v>40</v></c><c r="C5" t="b"><v>0</v></c></row>'
                '</sheetData>',
          },
        ),
      );
      expect(await source.columnNames(), ['name', 'n', 'ok', 'note']);
      expect(await source.estimatedRowCount(), 2);
      expect(await rowsOf(source), [
        ['padded', 20, true, 'padded!'],
        ['x', 6.5, null, null],
        [null, 40, false, null], // row 4 is not stored, row 5 has gaps
      ]);
      expect((await rowsOf(source))[0][1], isA<int>());
      expect((await rowsOf(source))[1][1], isA<double>());
      // rows() can be iterated again
      expect((await rowsOf(source)).length, 3);
    });

    test(
      'dates: built-in and custom formats, times, the 1900 gap, 1904',
      () async {
        Uint8List book({bool date1904 = false}) => buildXlsx(
          date1904: date1904,
          numFmts:
              '<numFmt numFmtId="164" formatCode="yyyy\\-mm\\-dd"/>'
              '<numFmt numFmtId="165" formatCode="&quot;Day &quot;0"/>'
              '<numFmt numFmtId="166" formatCode="[h]:mm"/>',
          cellXfs:
              '<xf numFmtId="0"/><xf numFmtId="14"/><xf numFmtId="164"/>'
              '<xf numFmtId="165"/><xf numFmtId="22"/><xf numFmtId="166"/>',
          sheets: {
            'S':
                '<sheetData>'
                '<row><c t="inlineStr"><is><t>a</t></is></c><c t="inlineStr"><is><t>b</t></is></c>'
                '<c t="inlineStr"><is><t>c</t></is></c><c t="inlineStr"><is><t>d</t></is></c>'
                '<c t="inlineStr"><is><t>e</t></is></c><c t="inlineStr"><is><t>f</t></is></c></row>'
                '<row><c s="1"><v>45803</v></c><c s="2"><v>1</v></c><c s="3"><v>45803</v></c>'
                '<c s="4"><v>45803.5</v></c><c s="5"><v>1.25</v></c><c s="2"><v>61</v></c></row>'
                '</sheetData>',
          },
        );
        final row = (await rowsOf(XlsxDataSource.fromData(book()))).single;
        expect(row[0], DateTime.utc(2025, 5, 26)); // built-in 14
        expect(row[1], DateTime.utc(1900, 1, 1)); // custom date code, serial 1
        expect(row[2], 45803); // "Day "0 is not a date format
        expect(row[3], DateTime.utc(2025, 5, 26, 12)); // built-in 22, with time
        expect(row[4], DateTime.utc(1900, 1, 1, 6)); // elapsed [h]:mm is a time
        expect(row[5], DateTime.utc(1900, 3, 1)); // after Excel's fake Feb 29
        final row1904 = (await rowsOf(
          XlsxDataSource.fromData(book(date1904: true)),
        )).single;
        expect(row1904[1], DateTime.utc(1904, 1, 2));
        expect(XlsxWorkbook.isDateFormat('#,##0.00'), isFalse);
        expect(XlsxWorkbook.isDateFormat('General'), isFalse);
        expect(XlsxWorkbook.isDateFormat('[Red]0.0'), isFalse);
        expect(XlsxWorkbook.isDateFormat('d/m/yyyy h:mm'), isTrue);
        expect(XlsxWorkbook.isDateFormat('"m"0'), isFalse);
      },
    );

    test('sheet selection, skipped rows, no header, blank and duplicate '
        'names, trim', () async {
      final bytes = buildXlsx(
        sharedStrings: ['Title', 'a', ' b ', 'x'],
        sheets: {
          'First': '<sheetData><row r="1"><c r="A1" t="s"><v>3</v></c></row></sheetData>',
          'Second':
              '<sheetData>'
              '<row r="1"><c r="A1" t="s"><v>0</v></c></row>'
              '<row r="3"><c r="A3" t="s"><v>1</v></c><c r="B3" t="s"><v>1</v></c>'
              '<c r="D3" t="s"><v>2</v></c></row>'
              '<row r="4"><c r="A4"><v>1</v></c><c r="B4"><v>2</v></c>'
              '<c r="C4"><v>3</v></c><c r="D4" t="s"><v>2</v></c><c r="E4"><v>5</v></c></row>'
              '</sheetData>',
        },
      );
      final first = XlsxDataSource.fromData(bytes);
      expect(await first.columnNames(), ['x']);
      expect(await first.estimatedRowCount(), isNull); // no dimension
      final second = XlsxDataSource.fromData(
        bytes,
        options: const XlsxOptions(sheet: 'Second', skipRows: 2),
      );
      // blank C → letter, duplicate a → a_2, " b " trimmed; E is dropped
      expect(await second.columnNames(), ['a', 'a_2', 'C', 'b']);
      expect(await rowsOf(second), [
        [1, 2, 3, 'b'],
      ]);
      final raw = XlsxDataSource.fromData(
        bytes,
        options: const XlsxOptions(
          sheet: 'Second',
          skipRows: 2,
          hasHeader: false,
          trim: false,
        ),
      );
      expect(await raw.columnNames(), ['A', 'B', 'C', 'D']);
      expect((await rowsOf(raw)).first, ['a', 'a', null, ' b ']);
      expect(
        () => XlsxDataSource.fromData(
          bytes,
          options: const XlsxOptions(sheet: 'Nope'),
        ).columnNames(),
        throwsArgumentError,
      );
      expect(
        () =>
            XlsxDataSource.fromData(Uint8List.fromList([1, 2, 3]))
                .columnNames(),
        throwsA(anything),
      );
    });

    test('fromBytes re-opens per iteration', () async {
      var opened = 0;
      final bytes = buildXlsx(
        sheets: {
          'S':
              '<sheetData><row><c t="inlineStr"><is><t>h</t></is></c></row>'
              '<row><c><v>1</v></c></row></sheetData>',
        },
      );
      final source = XlsxDataSource.fromBytes(() async {
        opened++;
        return bytes;
      });
      expect(await rowsOf(source), [
        [1],
      ]);
      expect(await rowsOf(source), [
        [1],
      ]);
      expect(opened, 2);
    });
  });
}
