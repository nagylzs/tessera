import 'dart:io';

import 'package:test/test.dart';
import 'package:tessera_xlsx/tessera_xlsx.dart';

void main() {
  test('example/main.dart round-trips sales.xlsx', () async {
    final dir = Directory.systemTemp.createTempSync('tessera_xlsx_example');
    try {
      final out = '${dir.path}/pivot.xlsx';
      final result = await Process.run(Platform.resolvedExecutable, [
        'run',
        'example/main.dart',
        'example/sales.xlsx',
        out,
      ]);
      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(result.stdout, contains('1000 facts, 11 columns'));
      expect(result.stdout, contains('Wrote $out'));
      // the export reads back: 2 column levels + aggregate row, then the
      // expanded regions with their countries
      final rows = await XlsxDataSource.fromData(
        File(out).readAsBytesSync(),
        options: const XlsxOptions(hasHeader: false),
      ).rows().toList();
      expect(rows[2].take(2), ['region', 'country']);
      expect(rows.any((r) => r[1] == 'Hungary'), isTrue);
      expect(rows.last.first, 'Total');
    } finally {
      dir.deleteSync(recursive: true);
    }
  });
}
