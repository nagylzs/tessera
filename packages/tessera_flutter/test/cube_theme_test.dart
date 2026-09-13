import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tessera_flutter/tessera_flutter.dart';

Future<ResolvedCubeTheme> resolve(
  WidgetTester tester,
  CubeTheme theme, {
  Brightness brightness = Brightness.light,
  Color seed = Colors.teal,
}) async {
  late ResolvedCubeTheme resolved;
  await tester.pumpWidget(
    Theme(
      data: ThemeData(colorSchemeSeed: seed, brightness: brightness),
      child: Builder(
        builder: (context) {
          resolved = theme.resolve(context);
          return const SizedBox();
        },
      ),
    ),
  );
  return resolved;
}

const level = CellLevel(row: 0, column: 0, rowLevels: 2, columnLevels: 2);
const rowHeader = HeaderLevel(
  isRow: true,
  level: 1,
  rowLevels: 2,
  columnLevels: 2,
);
const columnHeader = HeaderLevel(
  isRow: false,
  level: 0,
  rowLevels: 2,
  columnLevels: 2,
);

void main() {
  test('CellLevel and HeaderLevel arithmetic', () {
    const c = CellLevel(row: 1, column: 2, rowLevels: 2, columnLevels: 3);
    expect(c.depth, 3);
    expect(c.maxDepth, 3);
    expect(
      const CellLevel(
        row: 0,
        column: 0,
        rowLevels: 0,
        columnLevels: 2,
      ).maxDepth,
      1,
    );
    expect(rowHeader.levels, 2);
    expect(rowHeader.index, 1);
    expect(columnHeader.index, 2); // after the two row levels
  });

  testWidgets('defaults: a gradient by depth, one header colour', (
    tester,
  ) async {
    final t = await resolve(tester, const CubeTheme());
    final top = t.levelColor(level);
    final deep = t.levelColor(
      const CellLevel(row: 1, column: 1, rowLevels: 2, columnLevels: 2),
    );
    expect(top, isNot(deep));
    expect(t.headerLevelColor(rowHeader), t.headerColor);
    expect(t.headerLevelColor(columnHeader), t.headerColor);
    // an explicit header colour applies to every level
    final pinned = await resolve(
      tester,
      const CubeTheme(headerColor: Colors.red),
    );
    expect(pinned.headerLevelColor(rowHeader), Colors.red);
  });

  testWidgets('hueLevels: hue from the primary, per level, light and dark', (
    tester,
  ) async {
    final light = await resolve(
      tester,
      const CubeTheme(hueLevels: HueLevels()),
    );
    final primary = Oklch.fromArgb(Colors.teal.toARGB32());
    Oklch of(Color c) => Oklch.fromArgb(c.toARGB32());
    final l0 = of(light.levelColor(level));
    final l1 = of(
      light.levelColor(
        const CellLevel(row: 1, column: 0, rowLevels: 2, columnLevels: 2),
      ),
    );
    // the first level takes the primary's hue, the next a different one,
    // both equally light; the column level does not change the colour
    expect((l0.hue - primary.hue).abs(), lessThan(8));
    expect((l1.hue - l0.hue).abs(), greaterThan(60));
    expect(l0.lightness, closeTo(l1.lightness, 0.012));
    expect(
      light.levelColor(
        const CellLevel(row: 1, column: 1, rowLevels: 2, columnLevels: 2),
      ),
      light.levelColor(
        const CellLevel(row: 1, column: 0, rowLevels: 2, columnLevels: 2),
      ),
    );
    // headers: the row header of level 1 shares its hue with its cells,
    // the column header continues the sequence
    final h1 = of(light.headerLevelColor(rowHeader));
    expect((h1.hue - l1.hue).abs(), lessThan(8));
    expect(h1.chroma, greaterThan(l1.chroma));
    final c0 = of(light.headerLevelColor(columnHeader));
    expect((c0.hue - h1.hue).abs(), greaterThan(30));
    expect(l0.lightness, greaterThan(0.9));

    final dark = await resolve(
      tester,
      const CubeTheme(hueLevels: HueLevels()),
      brightness: Brightness.dark,
    );
    expect(of(dark.levelColor(level)).lightness, lessThan(0.4));

    // an explicit hue and explicit level colours win
    final fixed = await resolve(
      tester,
      CubeTheme(
        hueLevels: const HueLevels(hue: 100),
        levelColor: (_) => Colors.white,
      ),
    );
    expect(fixed.levelColor(level), Colors.white);
    expect(
      (of(fixed.headerLevelColor(columnHeader)).hue -
              const HueLevels(hue: 100).hueAt(2))
          .abs(),
      lessThan(5),
    );
  });
}
