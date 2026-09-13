import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('example/main.dart draws sales.csv', () async {
    final dir = Directory.systemTemp.createTempSync('tessera_svg_example');
    try {
      final out = '${dir.path}/pivot.svg';
      final result = await Process.run(Platform.resolvedExecutable, [
        'run',
        'example/main.dart',
        'example/sales.csv',
        out,
      ]);
      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      final svg = File(out).readAsStringSync();
      expect(svg, contains('<title>Sales by region</title>'));
      expect(svg, contains('>Hungary</text>'));
      expect(svg, contains('<svg xmlns="http://www.w3.org/2000/svg"'));
    } finally {
      dir.deleteSync(recursive: true);
    }
  });
}
