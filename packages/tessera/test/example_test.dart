import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('example/main.dart round-trips sales.csv', () async {
    final dir = Directory.systemTemp.createTempSync('tessera_example');
    try {
      final out = '${dir.path}/pivot.csv';
      final result = await Process.run(Platform.resolvedExecutable, [
        'run',
        'example/main.dart',
        'example/sales.csv',
        out,
      ]);
      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(result.stdout, contains('1000 records, 11 columns'));
      expect(result.stdout, contains('Europe'));
      expect(result.stdout, contains('Wrote $out'));
      final lines = File(out).readAsLinesSync();
      expect(lines[2], startsWith('region,country,sum of total,count,'));
      expect(lines.any((l) => l.startsWith(',Hungary,')), isTrue);
      expect(lines.last, startsWith('Total,'));
    } finally {
      dir.deleteSync(recursive: true);
    }
  });
}
