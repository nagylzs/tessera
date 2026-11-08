import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tessera_flutter/tessera_flutter.dart';

const region = ColumnDimension('region');
const country = ColumnDimension('country');
const category = ColumnDimension('category');
const qty = Measure('qty');

Future<FactTable> facts() async {
  final source = ListDataSource(
    columns: ['region', 'country', 'category', 'qty'],
    // every cell its own value: Germany × A 1, Hungary 12, Europe 15,
    // Asia 16, the total 31
    rows: const [
      ['Europe', 'Germany', 'A', 1],
      ['Europe', 'Germany', 'B', 2],
      ['Europe', 'Hungary', 'A', 4],
      ['Europe', 'Hungary', 'B', 8],
      ['Asia', 'Japan', 'B', 16],
    ],
    declaredSchema: Schema([
      const ColumnSpec(name: 'region', type: ColumnType.text),
      const ColumnSpec(name: 'country', type: ColumnType.text),
      const ColumnSpec(name: 'category', type: ColumnType.text),
      const ColumnSpec(name: 'qty', type: ColumnType.integer),
    ]),
  );
  return (await loadFacts(source)).facts;
}

/// Distinct colours per role and depth, so a test can tell them apart.
final style = JsonCubeStyle.fromJson({
  'format': 'tessera-style',
  'version': 1,
  'id': 'test',
  'name': {'en': 'Test'},
  'metrics': {'rowHeight': 32, 'headerRowHeight': 30, 'padding': 5},
  'light': {
    'border': '#123456',
    'selection': '#FF00FF',
    'cell': {'fill': '#FFFFFF', 'text': '#101010', 'size': 12},
    'value': {
      'fill': ['#F00000', '#F10000', '#F20000'],
    },
    'rowLabel': {
      'fill': ['#A00000', '#A10000'],
      'bold': [true, false],
      'size': [16, 12],
    },
    'columnLabel': {'fill': '#B00000'},
    'title': {'family': 'serif', 'italic': true},
    'total': {'fill': '#900000', 'bold': true},
  },
  'dark': {
    'border': '#654321',
    'cell': {'fill': '#000000', 'text': '#EEEEEE'},
  },
});

Future<ResolvedCubeTheme> resolve(
  WidgetTester tester,
  CubeTheme theme, {
  Brightness brightness = Brightness.light,
}) async {
  late ResolvedCubeTheme resolved;
  await tester.pumpWidget(
    Theme(
      data: ThemeData(brightness: brightness),
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

void main() {
  late FactTable f;
  setUpAll(() async => f = await facts());

  ScreenLook look(ResolvedCubeTheme t, StyleCell cell) =>
      t.lookOf(cell, rowLevels: 2, columnLevels: 1);

  testWidgets('fromStyle: every role and depth, its sizes and colours', (
    tester,
  ) async {
    final t = await resolve(
      tester,
      CubeTheme.fromStyle(
        style,
        fontFamilies: const {StyleFamily.serif: 'Noto Serif'},
      ),
    );
    expect(t.rowHeight, 32);
    expect(t.headerRowHeight, 30);
    expect(t.cellPadding, const EdgeInsets.symmetric(horizontal: 5));
    expect(t.borderColor, const Color(0xFF123456));
    expect(t.selectionColor, const Color(0xFFFF00FF));
    final deep = look(
      t,
      const StyleCell(CellRole.value, rowLevel: 1, columnLevel: 1),
    );
    expect(deep.fill, const Color(0xFFF20000));
    expect(deep.text.color, const Color(0xFF101010));
    final europe = look(t, const StyleCell(CellRole.rowLabel, rowLevel: 0));
    expect(europe.fill, const Color(0xFFA00000));
    expect(europe.text.fontWeight, FontWeight.bold);
    expect(europe.text.fontSize, 16);
    final germany = look(t, const StyleCell(CellRole.rowLabel, rowLevel: 1));
    expect(germany.text.fontWeight, FontWeight.normal);
    expect(germany.text.fontSize, 12);
    final title = look(t, const StyleCell(CellRole.title, rowLevel: 0));
    expect(title.text.fontFamily, 'Noto Serif');
    expect(title.text.fontStyle, FontStyle.italic);
    // the plain fields follow the style too
    expect(
      t.levelColor(
        const CellLevel(row: 1, column: 0, rowLevels: 2, columnLevels: 1),
      ),
      const Color(0xFFF10000),
    );
    expect(t.summaryColor, const Color(0xFF900000));
  });

  testWidgets('fromStyle: the depth coloring, and the dark variant', (
    tester,
  ) async {
    const deep = StyleCell(CellRole.value, rowLevel: 1, columnLevel: 1);
    final rows = await resolve(
      tester,
      CubeTheme.fromStyle(style, coloring: DepthColoring.rows),
    );
    expect(look(rows, deep).fill, const Color(0xFFF10000));
    final off = await resolve(
      tester,
      CubeTheme.fromStyle(style, coloring: DepthColoring.off),
    );
    expect(look(off, deep).fill, const Color(0xFFF00000));
    final dark = await resolve(
      tester,
      CubeTheme.fromStyle(style),
      brightness: Brightness.dark,
    );
    expect(dark.borderColor, const Color(0xFF654321));
    expect(look(dark, deep).text.color, const Color(0xFFEEEEEE));
    // fonts from light
    expect(
      look(dark, const StyleCell(CellRole.rowLabel, rowLevel: 0)).text.fontSize,
      16,
    );
  });

  testWidgets('a theme of plain fields looks as its fields say', (
    tester,
  ) async {
    final t = await resolve(
      tester,
      const CubeTheme(summaryColor: Colors.amber, headerColor: Colors.cyan),
    );
    final total = look(t, const StyleCell(CellRole.total));
    expect(total.fill, Colors.amber);
    expect(total.text.fontWeight, FontWeight.bold);
    expect(look(t, const StyleCell(CellRole.corner)).fill, Colors.cyan);
    expect(
      look(
        t,
        const StyleCell(CellRole.value, rowLevel: 1, columnLevel: 0),
      ).fill,
      t.levelColor(
        const CellLevel(row: 1, column: 0, rowLevels: 2, columnLevels: 1),
      ),
    );
  });

  group('CubeView in a style', () {
    Widget host(Cube cube) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 1000,
          height: 700,
          child: CubeView(
            controller: CubeController(cube),
            theme: CubeTheme.fromStyle(style),
          ),
        ),
      ),
    );

    Cube cube() => Cube(
      facts: f,
      spec: CubeSpec(
        rows: CubeAxis.of([region, country]),
        columns: CubeAxis.of([category]),
        aggregates: [Aggregate.sum(qty)],
      ),
    ).toggleRow(DimensionPath([const DimensionValue(region, 'Europe')]));

    Color fillOf(WidgetTester tester, Finder text) => tester
        .widget<Container>(
          find.ancestor(of: text, matching: find.byType(Container)).first,
        )
        .color!;

    TextStyle styleOf(WidgetTester tester, Finder text) =>
        tester.widget<Text>(text).style!;

    testWidgets('each cell as the style has it', (tester) async {
      await tester.pumpWidget(host(cube()));
      await tester.pumpAndSettle();
      final europe = find.text('Europe');
      final germany = find.text('Germany');
      expect(fillOf(tester, europe), const Color(0xFFA00000));
      expect(styleOf(tester, europe).fontWeight, FontWeight.bold);
      expect(styleOf(tester, europe).fontSize, 16);
      expect(fillOf(tester, germany), const Color(0xFFA10000));
      expect(styleOf(tester, germany).fontWeight, FontWeight.normal);
      // Germany × A: row depth 1, column depth 0
      final one = find.text('1');
      expect(fillOf(tester, one), const Color(0xFFF10000));
      // the grand total
      final total = find.text('31');
      expect(fillOf(tester, total), const Color(0xFF900000));
      expect(styleOf(tester, total).fontWeight, FontWeight.bold);
      expect(fillOf(tester, find.text('A')), const Color(0xFFB00000));
      expect(styleOf(tester, find.text('region')).fontStyle, FontStyle.italic);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a larger font widens its column', (tester) async {
      double headerWidth(WidgetTester tester) =>
          tester.getSize(find.text('Hungary')).width;
      await tester.pumpWidget(host(cube()));
      await tester.pumpAndSettle();
      final europeWidth = tester
          .getSize(
            find
                .ancestor(
                  of: find.text('Europe'),
                  matching: find.byType(Container),
                )
                .first,
          )
          .width;
      // the first level's labels at 16 fit their column
      final text = tester.getSize(find.text('Europe')).width;
      expect(europeWidth, greaterThanOrEqualTo(text));
      expect(headerWidth(tester), greaterThan(0));
    });
  });

  testWidgets('the preview draws every role, light and dark', (tester) async {
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 240,
              height: 180,
              child: CubeStylePreview(
                theme: CubeTheme.fromStyle(style),
                brightness: brightness,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('January'), findsOneWidget);
      expect(find.text('Q1'), findsOneWidget);
      expect(find.text('Total'), findsNWidgets(2));
      // a row label of the first level: light's, or dark's own cell
      final fills = [
        for (final box in tester.widgetList<DecoratedBox>(
          find.ancestor(
            of: find.text('January'),
            matching: find.byType(DecoratedBox),
          ),
        ))
          if (box.decoration case BoxDecoration(:final color?)) color,
      ];
      expect(
        fills.first,
        brightness == Brightness.light
            ? const Color(0xFFA00000)
            : const Color(0xFF000000),
      );
      expect(tester.takeException(), isNull, reason: '$brightness');
    }
  });
}
