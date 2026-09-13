import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:tessera_xlsx/tessera_xlsx.dart';

void main() {
  test('the API is scaffolded but not implemented', () {
    final source = XlsxDataSource.fromData(Uint8List(0), name: 'x.xlsx');
    expect(source.name, 'x.xlsx');
    expect(source.declaredSchema, isNull);
    expect(source.options.hasHeader, isTrue);
    expect(() => source.rows(), throwsUnimplementedError);
    const exporter = XlsxCubeExporter();
    expect(exporter.strings.languageCode, 'en');
  });
}
