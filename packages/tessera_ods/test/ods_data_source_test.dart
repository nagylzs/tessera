import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:test/test.dart';
import 'package:tessera/tessera.dart';
import 'package:tessera_ods/tessera_ods.dart';

Future<List<List<Object?>>> rowsOf(DataSource s) => s.rows().toList();

/// A minimal document: [sheets] maps sheet names to the rows XML.
Uint8List buildOds(Map<String, String> sheets) {
  final archive = Archive();
  archive.add(
    ArchiveFile.string(
      'mimetype',
      'application/vnd.oasis.opendocument.spreadsheet',
    )..compression = CompressionType.none,
  );
  archive.add(
    ArchiveFile.string(
      'content.xml',
      '<office:document-content '
          'xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" '
          'xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0" '
          'xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0">'
          '<office:body><office:spreadsheet>'
          '${[for (final e in sheets.entries) '<table:table table:name="${e.key}">${e.value}</table:table>'].join()}'
          '</office:spreadsheet></office:body></office:document-content>',
    ),
  );
  return ZipEncoder().encodeBytes(archive);
}

String str(String s) =>
    '<table:table-cell office:value-type="string"><text:p>$s</text:p></table:table-cell>';
String num_(String v) =>
    '<table:table-cell office:value-type="float" office:value="$v"><text:p>$v</text:p></table:table-cell>';

void main() {
  group('OdsDataSource on a LibreOffice document', () {
    late Uint8List bytes;
    setUpAll(() => bytes = File('test/data/sales.ods').readAsBytesSync());

    test('imports the same facts as sales.csv', () async {
      final ods = OdsDataSource.fromData(bytes, name: 'sales.ods');
      final csv = CsvDataSource.fromData(
        File('../tessera/test/data/sales.csv').readAsBytesSync(),
        name: 'sales.csv',
      );
      expect(await ods.columnNames(), await csv.columnNames());
      expect(await ods.estimatedRowCount(), 1000);
      final a = (await loadFacts(ods)).facts;
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
      expect(a.valueAt(0, 'date'), DateTime.utc(2025, 5, 26));
    });

    test('is sendable to the import isolate', () async {
      final result = await loadFactsInIsolate(
        OdsDataSource.fromData(bytes, name: 'sales.ods'),
      );
      expect(result.facts.rowCount, 1000);
    });
  });

  group('OdsDataSource on hand-built documents', () {
    test('typed cells, repeats, spaces, annotations, sheets', () async {
      final bytes = buildOds({
        'First':
            '<table:table-row>${str('only')}</table:table-row>'
            '<table:table-row>${num_('1')}</table:table-row>',
        'Data':
            '<table:table-row>${str('n')}${str('when')}${str('ok')}${str('note')}${str('pct')}</table:table-row>'
            '<table:table-row>${num_('20')}'
            '<table:table-cell office:value-type="date" office:date-value="2025-05-26T10:30:00"><text:p>x</text:p></table:table-cell>'
            '<table:table-cell office:value-type="boolean" office:boolean-value="true"><text:p>TRUE</text:p></table:table-cell>'
            '<table:table-cell office:value-type="string"><text:p>a<text:s text:c="2"/>b</text:p><text:p>second</text:p>'
            '<office:annotation><text:p>ignored</text:p></office:annotation></table:table-cell>'
            '<table:table-cell office:value-type="percentage" office:value="0.25"><text:p>25%</text:p></table:table-cell>'
            '</table:table-row>'
            // gaps: two repeated empty cells, then a value; padding rows
            '<table:table-row>${num_('6.5')}<table:table-cell table:number-columns-repeated="2"/>${str(' padded ')}</table:table-row>'
            '<table:table-row table:number-rows-repeated="2">${num_('7')}</table:table-row>'
            '<table:table-row table:number-rows-repeated="1048000"><table:table-cell table:number-columns-repeated="1000"/></table:table-row>',
      });
      final data = OdsDataSource.fromData(
        bytes,
        options: const OdsOptions(sheet: 'Data'),
      );
      expect(await data.columnNames(), ['n', 'when', 'ok', 'note', 'pct']);
      expect(await data.estimatedRowCount(), 4);
      expect(await rowsOf(data), [
        [20, DateTime.utc(2025, 5, 26, 10, 30), true, 'a  b\nsecond', 0.25],
        [6.5, null, null, 'padded', null],
        [7, null, null, null, null],
        [7, null, null, null, null],
      ]);
      expect((await rowsOf(data))[0][0], isA<int>());
      // the first sheet by default; unknown sheets are an error
      expect(await OdsDataSource.fromData(bytes).columnNames(), ['only']);
      expect(
        () => OdsDataSource.fromData(
          bytes,
          options: const OdsOptions(sheet: 'Nope'),
        ).columnNames(),
        throwsArgumentError,
      );
      // not a spreadsheet
      expect(
        () =>
            OdsDataSource.fromData(Uint8List.fromList([1, 2, 3])).columnNames(),
        throwsA(anything),
      );
    });

    test('skipped rows, no header, blank and duplicate names, trim', () async {
      final bytes = buildOds({
        'S':
            '<table:table-row>${str('Title')}</table:table-row>'
            '<table:table-row/>'
            '<table:table-row>${str('a')}${str('a')}<table:table-cell/>${str(' b ')}</table:table-row>'
            '<table:table-row>${num_('1')}${num_('2')}${num_('3')}${str(' x ')}${num_('5')}</table:table-row>',
      });
      final s = OdsDataSource.fromData(
        bytes,
        options: const OdsOptions(skipRows: 2),
      );
      expect(await s.columnNames(), ['a', 'a_2', 'C', 'b']);
      expect(await rowsOf(s), [
        [1, 2, 3, 'x'],
      ]);
      final raw = OdsDataSource.fromData(
        bytes,
        options: const OdsOptions(skipRows: 2, hasHeader: false, trim: false),
      );
      expect(await raw.columnNames(), ['A', 'B', 'C', 'D']);
      expect((await rowsOf(raw)).first, ['a', 'a', null, ' b ']);
    });

    test('fromBytes re-opens per iteration', () async {
      var opened = 0;
      final bytes = buildOds({
        'S':
            '<table:table-row>${str('h')}</table:table-row>'
            '<table:table-row>${num_('1')}</table:table-row>',
      });
      final source = OdsDataSource.fromBytes(() async {
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
