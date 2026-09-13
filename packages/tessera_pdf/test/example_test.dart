import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('example/main.dart writes sales.csv as a PDF', () async {
    final dir = Directory.systemTemp.createTempSync('tessera_pdf_example');
    try {
      final out = '${dir.path}/pivot.pdf';
      final result = await Process.run(Platform.resolvedExecutable, [
        'run',
        'example/main.dart',
        'example/sales.csv',
        out,
      ]);
      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(result.stdout, contains('pages'));
      final bytes = File(out).readAsBytesSync();
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(bytes.length, greaterThan(5000));
    } finally {
      dir.deleteSync(recursive: true);
    }
  });
}
