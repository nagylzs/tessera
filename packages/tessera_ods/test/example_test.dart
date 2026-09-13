import 'dart:io';

import 'package:test/test.dart';
import 'package:tessera_ods/tessera_ods.dart';

void main() {
  test('example/main.dart round-trips sales.ods', () async {
    final dir = Directory.systemTemp.createTempSync('tessera_ods_example');
    try {
      final out = '${dir.path}/pivot.ods';
      final result = await Process.run(Platform.resolvedExecutable, [
        'run',
        'example/main.dart',
        'example/sales.ods',
        out,
      ]);
      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(result.stdout, contains('1000 facts, 11 columns'));
      final rows = await OdsDataSource.fromData(
        File(out).readAsBytesSync(),
        options: const OdsOptions(hasHeader: false),
      ).rows().toList();
      expect(rows[2].take(2), ['region', 'country']);
      expect(rows.any((r) => r[1] == 'Hungary'), isTrue);
      expect(rows.last.first, 'Total');
    } finally {
      dir.deleteSync(recursive: true);
    }
  });
}
