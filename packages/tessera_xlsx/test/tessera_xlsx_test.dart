import 'package:test/test.dart';
import 'package:tessera_xlsx/tessera_xlsx.dart';

void main() {
  test('defaults', () {
    const exporter = XlsxCubeExporter();
    expect(exporter.strings.languageCode, 'en');
    expect(exporter.style.freezeHeaders, isTrue);
    expect(const XlsxOptions().hasHeader, isTrue);
  });
}
