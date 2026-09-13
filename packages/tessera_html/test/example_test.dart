import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('example/main.dart writes a page from sales.csv', () async {
    final dir = Directory.systemTemp.createTempSync('tessera_html_example');
    try {
      final out = '${dir.path}/pivot.html';
      final result = await Process.run(Platform.resolvedExecutable, [
        'run',
        'example/main.dart',
        'example/sales.csv',
        out,
      ]);
      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      final html = File(out).readAsStringSync();
      expect(html, contains('<title>Sales by region</title>'));
      expect(html, contains('>Hungary<'));
      expect(html, contains('background: #00695c;'));
    } finally {
      dir.deleteSync(recursive: true);
    }
  });
}
