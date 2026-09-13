import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tessera_example/theming/presets.dart';
import 'package:tessera_flutter/tessera_flutter.dart';

void main() {
  testWidgets('every preset resolves under light and dark themes', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        Theme(
          data: ThemeData(brightness: brightness),
          child: Builder(
            builder: (context) {
              for (final p in themePresets) {
                final t = p.theme.resolve(context);
                expect(t.rowHeight, greaterThan(0), reason: p.name);
                const top = CellLevel(
                  row: 0,
                  column: 0,
                  rowLevels: 2,
                  columnLevels: 2,
                );
                const deep = CellLevel(
                  row: 1,
                  column: 1,
                  rowLevels: 2,
                  columnLevels: 2,
                );
                expect(t.levelColor(top), isA<Color>(), reason: p.name);
                expect(t.levelColor(deep), isA<Color>(), reason: p.name);
                expect(
                  t.headerLevelColor(
                    const HeaderLevel(
                      isRow: true,
                      level: 1,
                      rowLevels: 2,
                      columnLevels: 2,
                    ),
                  ),
                  isA<Color>(),
                  reason: p.name,
                );
              }
              return const SizedBox();
            },
          ),
        ),
      );
    }
    expect(themePresets.map((p) => p.name).toSet().length, themePresets.length);
  });

  test('every preset has an Excel counterpart; brand comes from the seed', () {
    for (final p in themePresets) {
      expect(p.xlsxTheme.levelFills, isNotEmpty, reason: p.name);
      expect(
        excelThemeFor(ExcelTheme.matchPreset, p, Colors.teal),
        same(p.xlsxTheme),
      );
    }
    final brand = excelThemeFor(
      ExcelTheme.brand,
      themePresets.first,
      Colors.indigo,
    );
    expect(brand.headerFill, Colors.indigo.toARGB32());
    expect(brand.headerFont.color, 0xFFFFFFFF);
    expect(
      excelThemeFor(
        ExcelTheme.plain,
        themePresets.first,
        Colors.teal,
      ).headerFill,
      const CubeExportTheme().headerFill,
    );
  });
}
