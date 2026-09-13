import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tessera_flutter/src/widgets/cell_border.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';
import 'package:tessera_flutter/tessera_flutter.dart';

const region = ColumnDimension('region');
const country = ColumnDimension('country');
const category = ColumnDimension('category');
const qty = Measure('qty');
final sumQty = Aggregate.sum(qty);

const _rows = <List<Object?>>[
  ['Europe', 'Germany', 'A', 1],
  ['Europe', 'Germany', 'B', 2],
  ['Europe', 'Hungary', 'A', 3],
  ['Europe', null, 'A', 4],
  ['Asia', 'Japan', 'B', 5],
  ['Asia', 'Japan', null, 6],
  [null, 'Iceland', 'A', 7],
  [null, null, null, null],
];

Future<FactTable> facts() async {
  final source = ListDataSource(
    columns: ['region', 'country', 'category', 'qty'],
    rows: _rows,
    declaredSchema: Schema([
      const ColumnSpec(name: 'region', type: ColumnType.text),
      const ColumnSpec(name: 'country', type: ColumnType.text),
      const ColumnSpec(name: 'category', type: ColumnType.text),
      const ColumnSpec(name: 'qty', type: ColumnType.integer),
    ]),
  );
  return (await loadFacts(source)).facts;
}

final europe = DimensionPath([const DimensionValue(region, 'Europe')]);

Widget host(CubeView view) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 1000, height: 700, child: view)),
);

/// The `▾` menu button of the dimension title [label].
Finder menuButtonOf(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(InkWell)),
  matching: find.byIcon(Icons.arrow_drop_down),
);

MenuItemButton menuItem(WidgetTester tester, String label) =>
    tester.widget(find.widgetWithText(MenuItemButton, label));

/// The expand/collapse icon on the row whose label is [label].
Finder toggleIconOf(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(Row)).first,
  matching: find.byType(InkWell),
);

void main() {
  late FactTable f;
  setUpAll(() async => f = await facts());

  group('AxisGeometry', () {
    test('rotated-L areas', () {
      final layout = Cube(
        facts: f,
        spec: CubeSpec(rows: CubeAxis.of([region, country])),
      ).toggleRow(europe).layout;
      // entries: ∅, Asia, Europe, ∅, Germany, Hungary, Σ
      final g = AxisGeometry(layout.rows);
      expect(g.levels, 2);
      final leaf0 = HeaderArea(
        path: DimensionPath([const DimensionValue(region, null)]),
        entryIndex: 0,
        levelStart: 0,
        levelSpan: 2,
        entryStart: 0,
        entrySpan: 1,
        isLabel: true,
      );
      expect(g.areaAt(0, 0), leaf0);
      expect(g.areaAt(1, 0), leaf0);
      final europeLabel = HeaderArea(
        path: europe,
        entryIndex: 2,
        levelStart: 0,
        levelSpan: 1,
        entryStart: 2,
        entrySpan: 4,
        isLabel: true,
      );
      expect(g.areaAt(0, 2), europeLabel);
      expect(g.areaAt(0, 3), europeLabel);
      expect(g.areaAt(0, 5), europeLabel);
      expect(
        g.areaAt(1, 2),
        HeaderArea(
          path: europe,
          entryIndex: 2,
          levelStart: 1,
          levelSpan: 1,
          entryStart: 2,
          entrySpan: 1,
          isLabel: false,
        ),
      );
      expect(
        g.areaAt(1, 4),
        HeaderArea(
          path: europe.child(const DimensionValue(country, 'Germany')),
          entryIndex: 4,
          levelStart: 1,
          levelSpan: 1,
          entryStart: 4,
          entrySpan: 1,
          isLabel: true,
        ),
      );
      expect(
        g.areaAt(0, 6),
        HeaderArea(
          path: DimensionPath.root,
          entryIndex: 6,
          levelStart: 0,
          levelSpan: 2,
          entryStart: 6,
          entrySpan: 1,
          isLabel: true,
        ),
      );
      expect(g.areaAt(1, 6), g.areaAt(0, 6));
    });

    test('subtotals below and hidden', () {
      Cube cube(SubtotalPosition p) => Cube(
        facts: f,
        spec: CubeSpec(
          rows: CubeAxis.of([region, country], subtotalPosition: p),
        ),
      ).toggleRow(europe);
      String? label(HeaderEntry e) =>
          e.isSummary ? 'Σ' : e.value as String? ?? '∅';
      final bottom = cube(SubtotalPosition.bottom).layout.rows;
      // entries: ∅, Asia, ∅, Germany, Hungary, Europe, Σ
      expect(bottom.entries.map(label), [
        '∅',
        'Asia',
        '∅',
        'Germany',
        'Hungary',
        'Europe',
        'Σ',
      ]);
      expect(bottom.descendantCount(5), 3);
      var g = AxisGeometry(bottom);
      expect(
        g.areaAt(0, 3),
        HeaderArea(
          path: europe,
          entryIndex: 5,
          levelStart: 0,
          levelSpan: 1,
          entryStart: 2,
          entrySpan: 4,
          isLabel: true,
        ),
      );
      expect(g.areaAt(0, 5), g.areaAt(0, 3));
      expect(g.areaAt(1, 5).isLabel, isFalse); // the leg, on the last row
      expect(g.areaAt(1, 5).entryStart, 5);
      final hidden = cube(SubtotalPosition.hidden).layout.rows;
      // entries: ∅, Asia, ∅, Germany, Hungary, Σ — Europe has no row
      expect(hidden.entries.map(label), [
        '∅',
        'Asia',
        '∅',
        'Germany',
        'Hungary',
        'Σ',
      ]);
      expect(hidden.indexOf(europe), -1);
      final group = hidden.entryFor(europe)!;
      expect(group.isExpanded, isTrue);
      expect(group.value, 'Europe');
      expect(group.factCount, 4);
      expect(
        hidden.entryFor(DimensionPath([const DimensionValue(region, 'Mars')])),
        isNull,
      );
      g = AxisGeometry(hidden);
      expect(
        g.areaAt(0, 4),
        HeaderArea(
          path: europe,
          entryIndex: -1,
          levelStart: 0,
          levelSpan: 1,
          entryStart: 2,
          entrySpan: 3,
          isLabel: true,
        ),
      );
      expect(g.areaAt(1, 4).isLabel, isTrue); // Hungary's own cell
    });

    test('summary at the start is not an ancestor', () {
      final layout = Cube(
        facts: f,
        spec: CubeSpec(
          rows: CubeAxis.of([
            region,
            country,
          ], summaryPosition: SummaryPosition.start),
        ),
      ).layout;
      final g = AxisGeometry(layout.rows);
      expect(g.areaAt(0, 0).entrySpan, 1);
      expect(g.areaAt(0, 1).entryIndex, 1);
    });
  });

  group('CubeView', () {
    late CubeController controller;

    setUp(() {
      controller = CubeController(
        Cube(
          facts: f,
          spec: CubeSpec(
            rows: CubeAxis.of([region, country]),
            columns: CubeAxis.of([category]),
            aggregates: [sumQty],
          ),
        ),
      );
    });

    testWidgets('renders headers, values and blanks', (tester) async {
      await tester.pumpWidget(
        host(CubeView(controller: controller, aggregates: [sumQty])),
      );
      // corner: dimension titles
      expect(find.text('category'), findsOneWidget);
      expect(find.text('region'), findsOneWidget);
      expect(find.text('country'), findsOneWidget);
      // row entries, column entries, summaries
      expect(find.text('Europe'), findsOneWidget);
      expect(find.text('Asia'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('Total'), findsNWidgets(2));
      expect(find.text('(empty)'), findsNWidgets(2));
      // aggregate label once per column (∅, A, B, Σ)
      expect(find.text('sum of qty'), findsNWidgets(4));
      // values: grand total, Europe total, Europe/A
      expect(find.text('28'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      // no expand icon on collapsed root? root is expanded → '−' shown twice (rows + columns)
      expect(find.byIcon(Icons.remove), findsNWidgets(2));
      // three collapsed regions + three collapsed categories... categories are last level → no icon
      expect(find.byIcon(Icons.add), findsNWidgets(3));
    });

    testWidgets('custom labels, formatter and styler', (tester) async {
      final styled = <Object?>[];
      await tester.pumpWidget(
        host(
          CubeView(
            controller: controller,
            aggregates: [sumQty],
            emptyGroupLabel: '—',
            rowSummaryLabel: 'All rows',
            columnSummaryLabel: 'All columns',
            formatCell: (cell, value) => '<$value>',
            styleCell: (cell, value) {
              styled.add(value);
              return const TextStyle(color: Colors.purple);
            },
          ),
        ),
      );
      expect(find.text('—'), findsNWidgets(2));
      expect(find.text('All rows'), findsOneWidget);
      expect(find.text('All columns'), findsOneWidget);
      expect(find.text('<28.0>'), findsOneWidget);
      expect(styled.length, 13); // every non-empty cell, null sums included
      final text = tester.widget<Text>(find.text('<28.0>'));
      expect(text.style?.color, Colors.purple);
      expect(text.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('header icons follow the header text colour', (tester) async {
      Color? iconColor() =>
          IconTheme.of(tester.element(find.byIcon(Icons.add).first)).color;
      await tester.pumpWidget(
        host(
          CubeView(
            controller: controller,
            aggregates: [sumQty],
            theme: const CubeTheme(
              headerTextStyle: TextStyle(color: Colors.purple),
            ),
          ),
        ),
      );
      expect(iconColor(), Colors.purple);
      await tester.pumpWidget(
        host(
          CubeView(
            controller: controller,
            aggregates: [sumQty],
            theme: const CubeTheme(
              headerTextStyle: TextStyle(color: Colors.purple),
              headerIconColor: Colors.orange,
            ),
          ),
        ),
      );
      expect(iconColor(), Colors.orange);
      // by default: the ambient text colour, not the ambient icon colour
      await tester.pumpWidget(
        host(CubeView(controller: controller, aggregates: [sumQty])),
      );
      final scheme = Theme.of(tester.element(find.text('Asia'))).colorScheme;
      expect(iconColor(), isNot(scheme.onSurfaceVariant));
      expect(
        iconColor(),
        Theme.of(tester.element(find.text('Asia'))).textTheme.bodySmall?.color,
      );
    });

    testWidgets('expanding a row group through the icon', (tester) async {
      await tester.pumpWidget(
        host(CubeView(controller: controller, aggregates: [sumQty])),
      );
      expect(find.text('Germany'), findsNothing);
      await tester.tap(toggleIconOf('Europe'));
      await tester.pumpAndSettle();
      expect(controller.cube.rowExpansion.isExpanded(europe), isTrue);
      expect(find.text('Germany'), findsOneWidget);
      expect(find.text('Hungary'), findsOneWidget);
      // Europe's subtotal is still shown, children below it
      expect(find.text('10'), findsOneWidget);
      await tester.tap(toggleIconOf('Europe'));
      await tester.pumpAndSettle();
      expect(find.text('Germany'), findsNothing);
    });

    testWidgets('large expansions ask for confirmation', (tester) async {
      var answer = false;
      final asked = <String>[];
      await tester.pumpWidget(
        host(
          CubeView(
            controller: controller,
            aggregates: [sumQty],
            expansionLimit: 2,
            confirmExpansion: (context, entry, {required isRow}) async {
              asked.add('${entry.label}:${entry.childCount}:$isRow');
              return answer;
            },
          ),
        ),
      );
      await tester.tap(toggleIconOf('Europe'));
      await tester.pumpAndSettle();
      expect(asked, ['Europe:3:true']);
      expect(find.text('Germany'), findsNothing);
      answer = true;
      await tester.tap(toggleIconOf('Europe'));
      await tester.pumpAndSettle();
      expect(find.text('Germany'), findsOneWidget);
      // Asia has one child → below the limit, no question
      await tester.tap(toggleIconOf('Asia'));
      await tester.pumpAndSettle();
      expect(asked.length, 2);
      expect(find.text('Japan'), findsOneWidget);
    });

    testWidgets('tapping a dimension title sorts that level by value', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(CubeView(controller: controller, aggregates: [sumQty])),
      );
      expect(find.byIcon(Icons.arrow_upward), findsNWidgets(3));
      await tester.tap(find.text('region'));
      await tester.pumpAndSettle();
      final sort = controller.cube.spec.rows.dimensions[0].sort!;
      expect(sort.by, SortBy.value);
      expect(sort.direction, SortDirection.descending);
      // country inherits the direction and shows it faded
      expect(find.byIcon(Icons.arrow_downward), findsNWidgets(2));
      expect(
        find.ancestor(
          of: find.byIcon(Icons.arrow_downward),
          matching: find.byType(Opacity),
        ),
        findsOneWidget,
      );
      expect(controller.cube.layout.rows.entries.map((e) => e.label).take(3), [
        '',
        'Europe',
        'Asia',
      ]);
      await tester.tap(find.text('region'));
      await tester.pumpAndSettle();
      expect(
        controller.cube.spec.rows.dimensions[0].sort!.direction,
        SortDirection.ascending,
      );
    });

    testWidgets('tapping the aggregate under a column sorts rows by it', (
      tester,
    ) async {
      // the summary column lies beyond the default 800 px test surface
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        host(CubeView(controller: controller, aggregates: [sumQty])),
      );
      // columns: ∅, A, B, Σ → the second "sum of qty" is under A
      await tester.tap(find.text('sum of qty').at(1));
      await tester.pumpAndSettle();
      final byA = DimensionPath([const DimensionValue(category, 'A')]);
      // the first level gets the sort, the deeper ones inherit it
      expect(controller.cube.spec.rows.dimensions[1].sort, isNull);
      for (var i = 0; i < 2; i++) {
        final s = controller.cube.spec.rows.sortAt(i);
        expect(s.by, SortBy.aggregate);
        expect(s.aggregate, sumQty);
        expect(s.keyPath, byA);
        expect(s.direction, SortDirection.descending);
      }
      // A column: Europe 8, ∅ 7, Asia none
      expect(
        controller.cube.layout.rows.entries.map(
          (e) => e.isSummary ? 'Σ' : e.value ?? '∅',
        ),
        ['Europe', '∅', 'Asia', 'Σ'],
      );
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
      // tapping again flips the direction
      await tester.tap(find.text('sum of qty').at(1));
      await tester.pumpAndSettle();
      expect(
        controller.cube.spec.rows.dimensions[0].sort!.direction,
        SortDirection.ascending,
      );
      // sorting by the summary column uses keyPath == null
      await tester.tap(find.text('sum of qty').at(3));
      await tester.pumpAndSettle();
      expect(controller.cube.spec.rows.dimensions[0].sort!.keyPath, isNull);
    });

    testWidgets('sortable: false ignores taps', (tester) async {
      await tester.pumpWidget(
        host(
          CubeView(
            controller: controller,
            aggregates: [sumQty],
            sortable: false,
          ),
        ),
      );
      await tester.tap(find.text('region'));
      await tester.pumpAndSettle();
      expect(controller.cube.spec.rows.dimensions[0].sort, isNull);
    });

    testWidgets('a deeper level cycles through desc, asc and inheriting', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      controller.cube = controller.cube.toggleRow(europe);
      await tester.pumpWidget(
        host(CubeView(controller: controller, aggregates: [sumQty])),
      );
      AxisSort? own() => controller.cube.spec.rows.dimensions[1].sort;
      List<String> europeChildren() => [
        for (final e in controller.cube.layout.rows.entries)
          if (e.depth == 2) e.value as String? ?? '∅',
      ];
      expect(own(), isNull);
      expect(europeChildren(), ['∅', 'Germany', 'Hungary']);
      // inherits ascending → the first tap is descending
      await tester.tap(find.text('country'));
      await tester.pumpAndSettle();
      expect(own()!.direction, SortDirection.descending);
      expect(europeChildren(), ['∅', 'Hungary', 'Germany']);
      await tester.tap(find.text('country'));
      await tester.pumpAndSettle();
      expect(own()!.direction, SortDirection.ascending);
      await tester.tap(find.text('country'));
      await tester.pumpAndSettle();
      expect(own(), isNull);
      // the user's scenario: aggregate sort on all levels, then a value
      // sort on the countries, then back to the aggregate order
      await tester.tap(find.text('sum of qty').last); // summary column
      await tester.pumpAndSettle();
      await tester.tap(find.text('sum of qty').last); // ascending
      await tester.pumpAndSettle();
      expect(controller.cube.spec.rows.sortAt(1).by, SortBy.aggregate);
      expect(europeChildren(), ['Germany', 'Hungary', '∅']); // 3, 3, 4
      await tester.tap(find.text('country'));
      await tester.pumpAndSettle();
      expect(own()!.by, SortBy.value);
      expect(europeChildren(), ['∅', 'Hungary', 'Germany']);
      // the menu offers inheriting directly
      await tester.longPress(find.text('country'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Same order as the level above'));
      await tester.pumpAndSettle();
      expect(own(), isNull);
      expect(europeChildren(), ['Germany', 'Hungary', '∅']);
      // the first level has no such item
      await tester.longPress(find.text('region'));
      await tester.pumpAndSettle();
      expect(find.text('Same order as the level above'), findsNothing);
    });

    testWidgets('the title menu expands and collapses a whole level', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(CubeView(controller: controller, aggregates: [sumQty])),
      );
      // long press opens the menu
      await tester.longPress(find.text('region'));
      await tester.pumpAndSettle();
      expect(find.text('Expand all'), findsOneWidget);
      expect(menuItem(tester, 'Collapse all').enabled, isFalse);
      await tester.tap(find.text('Expand all'));
      await tester.pumpAndSettle();
      expect(find.text('Expand all'), findsNothing);
      for (final label in ['Germany', 'Hungary', 'Japan', 'Iceland']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(controller.cube.layout.rows.length, 10);
      // the ▾ button opens it too; now the level can be collapsed
      await tester.tap(menuButtonOf('region'));
      await tester.pumpAndSettle();
      expect(menuItem(tester, 'Collapse all').enabled, isTrue);
      await tester.tap(find.text('Collapse all'));
      await tester.pumpAndSettle();
      expect(find.text('Germany'), findsNothing);
      expect(controller.cube.rowExpansion, ExpansionState.initial());
      // the last level has nothing to expand
      await tester.longPress(find.text('country'));
      await tester.pumpAndSettle();
      expect(menuItem(tester, 'Expand all').enabled, isFalse);
    });

    testWidgets('the title menu sets the sort direction', (tester) async {
      await tester.pumpWidget(
        host(CubeView(controller: controller, aggregates: [sumQty])),
      );
      // secondary click opens the menu
      await tester.tap(find.text('region'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      expect(find.text('Sort ascending'), findsOneWidget);
      await tester.tap(find.text('Sort descending'));
      await tester.pumpAndSettle();
      AxisSort sort() => controller.cube.spec.rows.dimensions[0].sort!;
      expect(sort().direction, SortDirection.descending);
      // choosing it again keeps it, unlike the tap toggle
      await tester.tap(menuButtonOf('region'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sort descending'));
      await tester.pumpAndSettle();
      expect(sort().direction, SortDirection.descending);
      // columns too
      await tester.tap(menuButtonOf('category'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sort descending'));
      await tester.pumpAndSettle();
      expect(
        controller.cube.spec.columns.dimensions[0].sort!.direction,
        SortDirection.descending,
      );
    });

    testWidgets('sortable: false leaves only expand/collapse in the menu', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          CubeView(
            controller: controller,
            aggregates: [sumQty],
            sortable: false,
          ),
        ),
      );
      await tester.tap(menuButtonOf('region'));
      await tester.pumpAndSettle();
      expect(find.text('Sort ascending'), findsNothing);
      expect(find.text('Expand all'), findsOneWidget);
    });

    testWidgets('large level expansions ask for confirmation', (tester) async {
      var answer = false;
      final asked = <String>[];
      await tester.pumpWidget(
        host(
          CubeView(
            controller: controller,
            aggregates: [sumQty],
            expansionLimit: 2,
            confirmLevelExpansion:
                (context, dimension, added, {required isRow}) async {
                  asked.add('${dimension.id}:$added:$isRow');
                  return answer;
                },
          ),
        ),
      );
      await tester.tap(menuButtonOf('region'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Expand all'));
      await tester.pumpAndSettle();
      expect(asked, ['region:6:true']);
      expect(find.text('Germany'), findsNothing);
      answer = true;
      await tester.tap(menuButtonOf('region'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Expand all'));
      await tester.pumpAndSettle();
      expect(find.text('Germany'), findsOneWidget);
      // the default dialog names the dimension
      await tester.pumpWidget(
        host(
          CubeView(
            controller: CubeController(controller.cube.collapseRowLevel(0)),
            aggregates: [sumQty],
            expansionLimit: 2,
          ),
        ),
      );
      await tester.tap(menuButtonOf('region'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Expand all'));
      await tester.pumpAndSettle();
      expect(
        find.text('Expanding "region" adds 6 rows. Continue?'),
        findsOneWidget,
      );
      await tester.tap(find.text('Expand'));
      await tester.pumpAndSettle();
      expect(find.text('Germany'), findsOneWidget);
    });

    testWidgets('cell levels add the row and column depths', (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final seen = <(int, int)>{};
      const qtyDim = ColumnDimension('qty');
      final cube = Cube(
        facts: f,
        spec: CubeSpec(
          rows: CubeAxis.of([region, country]),
          columns: CubeAxis.of([category, qtyDim]),
          aggregates: [sumQty],
        ),
      );
      final a = DimensionPath([const DimensionValue(category, 'A')]);
      await tester.pumpWidget(
        host(
          CubeView(
            controller: CubeController(cube.toggleRow(europe).toggleColumn(a)),
            aggregates: [sumQty],
            theme: CubeTheme(
              levelColor: (level) {
                seen.add((level.depth, level.maxDepth));
                return Colors.transparent;
              },
            ),
          ),
        ),
      );
      // Europe × A = 0, Germany × A = 1, Europe × A/1 = 1, Germany × A/1 = 2
      expect(seen, {(0, 2), (1, 2), (2, 2)});
    });

    testWidgets('no hairline between an expanded label and its leg', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      List<CellBorder> borders() => [
        for (final w in tester.widgetList<CustomPaint>(
          find.byType(CustomPaint),
        ))
          if (w.foregroundPainter case final CellBorder b) b,
      ];
      const qtyDim = ColumnDimension('qty');
      final cube = Cube(
        facts: f,
        spec: CubeSpec(
          rows: CubeAxis.of([region, country]),
          columns: CubeAxis.of([category, qtyDim]),
          aggregates: [sumQty],
        ),
      );
      final a = DimensionPath([const DimensionValue(category, 'A')]);
      final controller = CubeController(cube);
      await tester.pumpWidget(
        host(CubeView(controller: controller, aggregates: [sumQty])),
      );
      expect(
        borders().every((b) => b.rightFrom == 0 && b.bottomFrom == 0),
        isTrue,
      );
      controller.cube = cube.toggleRow(europe).toggleColumn(a);
      await tester.pumpAndSettle();
      // Europe's label skips its own row; A's label skips its own column
      expect(borders().where((b) => b.rightFrom > 0).length, 1);
      expect(borders().where((b) => b.bottomFrom > 0).length, 1);
      final europeBox = find.ancestor(
        of: find.text('Europe'),
        matching: find.byType(CustomPaint),
      );
      final europeBorder =
          tester.widget<CustomPaint>(europeBox.first).foregroundPainter
              as CellBorder;
      expect(europeBorder.rightFrom, const CubeTheme().rowHeight);
      expect(europeBorder.bottomFrom, 0);
      final aBox = find.ancestor(
        of: find.text('A'),
        matching: find.byType(CustomPaint),
      );
      final aBorder =
          tester.widget<CustomPaint>(aBox.first).foregroundPainter
              as CellBorder;
      expect(aBorder.rightFrom, 0);
      // the leg's column is the first of A's span, which is 4 columns wide
      final aWidth = tester.getSize(aBox.first).width;
      expect(aBorder.bottomFrom, greaterThan(0));
      expect(aBorder.bottomFrom, lessThan(aWidth));
      // subtotals below: the leg is the last row, so the border stops
      // before it; hidden: no leg, full border
      for (final (position, from, until) in [
        (SubtotalPosition.bottom, 0.0, 3 * const CubeTheme().rowHeight),
        (SubtotalPosition.hidden, 0.0, double.infinity),
      ]) {
        controller.cube = Cube(
          facts: f,
          spec: CubeSpec(
            rows: CubeAxis.of([region, country], subtotalPosition: position),
            columns: CubeAxis.of([category, qtyDim]),
            aggregates: [sumQty],
          ),
        ).toggleRow(europe);
        await tester.pumpAndSettle();
        final b =
            tester
                    .widget<CustomPaint>(
                      find
                          .ancestor(
                            of: find.text('Europe'),
                            matching: find.byType(CustomPaint),
                          )
                          .first,
                    )
                    .foregroundPainter
                as CellBorder;
        expect(b.rightFrom, from, reason: '$position');
        expect(b.rightUntil, until, reason: '$position');
      }
    });

    test('currentCell resolves the selection against the layout', () {
      final germany = europe.child(const DimensionValue(country, 'Germany'));
      final address = CellAddress(row: germany, column: DimensionPath.root);
      expect(controller.currentCell, isNull);
      controller.selection = address;
      expect(controller.currentCell, isNull); // Europe is collapsed
      controller.toggleRow(europe);
      expect(controller.currentCell!.factCount, 2);
      expect(controller.currentCell!.aggregate(sumQty), 3);
      controller.toggleRow(europe);
      expect(controller.currentCell, isNull);
      expect(controller.selection, address); // kept, not cleared
      var notified = 0;
      controller.addListener(() => notified++);
      controller.selection = address; // same → no notification
      controller.selection = null;
      expect(notified, 1);
    });

    testWidgets('tapping a data cell makes it the current cell', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final tapped = <CubeCell>[];
      await tester.pumpWidget(
        host(
          CubeView(
            controller: controller,
            aggregates: [sumQty],
            onCellTap: tapped.add,
          ),
        ),
      );
      List<CellBorder> outlined() => [
        for (final w in tester.widgetList<CustomPaint>(
          find.byType(CustomPaint),
        ))
          if (w.foregroundPainter case final CellBorder b
              when b.outline != null)
            b,
      ];
      expect(outlined(), isEmpty);
      await tester.tap(find.text('10')); // Europe × Σ
      await tester.pumpAndSettle();
      expect(
        controller.selection,
        CellAddress(row: europe, column: DimensionPath.root, aggregate: sumQty),
      );
      expect(controller.currentCell!.factCount, 4);
      expect(tapped.single.factCount, 4);
      expect(outlined().length, 1);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'CubeView');
      // the row and column headers of the current cell are tinted: the
      // "Europe" label and the column summary's "Total", nothing else
      final scheme = Theme.of(tester.element(find.text('Europe'))).colorScheme;
      Color tinted(Color base) =>
          Color.alphaBlend(scheme.primary.withValues(alpha: 0.15), base);
      final tintedHeader = tinted(scheme.surfaceContainer);
      final tintedSummary = tinted(scheme.surfaceContainerHighest);
      Iterable<Container> withColor(Color c) => tester
          .widgetList<Container>(find.byType(Container))
          .where((w) => w.color == c);
      expect(withColor(tintedHeader).length, 1);
      expect(withColor(tintedSummary).length, 1);
      // expanded: the label and its leg, the whole rotated L, are tinted
      controller.toggleRow(europe);
      await tester.pumpAndSettle();
      expect(withColor(tintedHeader).length, 2);
      controller.toggleRow(europe);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byWidgetPredicate(
            (w) => w is Container && w.color == tintedHeader,
          ),
          matching: find.text('Europe'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('selectable: false only reports taps', (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final tapped = <CubeCell>[];
      await tester.pumpWidget(
        host(
          CubeView(
            controller: controller,
            aggregates: [sumQty],
            selectable: false,
            onCellTap: tapped.add,
          ),
        ),
      );
      await tester.tap(find.text('10'));
      await tester.pumpAndSettle();
      expect(controller.selection, isNull);
      expect(tapped.length, 1);
      expect(FocusManager.instance.primaryFocus?.debugLabel, isNot('CubeView'));
    });

    testWidgets('the keyboard moves the current cell', (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        host(CubeView(controller: controller, aggregates: [sumQty])),
      );
      // rows: ∅, Asia, Europe, Σ; columns: ∅, A, B, Σ
      final asia = DimensionPath([const DimensionValue(region, 'Asia')]);
      final byB = DimensionPath([const DimensionValue(category, 'B')]);
      Future<void> key(LogicalKeyboardKey k) async {
        await tester.sendKeyEvent(k);
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('10')); // Europe × Σ
      await tester.pumpAndSettle();
      await key(LogicalKeyboardKey.arrowUp);
      expect(controller.selection!.row, asia);
      await key(LogicalKeyboardKey.arrowRight); // clamped at the last column
      expect(controller.selection!.column, DimensionPath.root);
      await key(LogicalKeyboardKey.arrowLeft);
      expect(controller.selection!.column, byB);
      await key(LogicalKeyboardKey.home);
      expect(controller.selection!.column.entries.single.value, isNull);
      await key(LogicalKeyboardKey.end);
      expect(controller.selection!.column, DimensionPath.root);
      await key(LogicalKeyboardKey.escape);
      expect(controller.selection, isNull);
      // with nothing selected a movement key selects the first cell
      await key(LogicalKeyboardKey.arrowDown);
      expect(controller.selection!.row.length, 1);
      expect(controller.selection!.row.entries.single.value, isNull);
      expect(controller.selection!.column.entries.single.value, isNull);
      // Ctrl+Home/End: first/last row, same column
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await key(LogicalKeyboardKey.home);
      expect(controller.selection!.row.entries.single.value, isNull); // ∅
      expect(controller.selection!.column.entries.single.value, isNull);
      await key(LogicalKeyboardKey.end);
      expect(controller.selection!.row.isRoot, isTrue);
      expect(controller.selection!.column.entries.single.value, isNull);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      // the number block's Home/End (numpad7/1 without a character while
      // NumLock is off) work too; with NumLock on they are digits
      await tester.tap(find.text('10'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.numpad7, character: '');
      await tester.pumpAndSettle();
      expect(controller.selection!.column.entries.single.value, isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.numpad1, character: '');
      await tester.pumpAndSettle();
      expect(controller.selection!.column, DimensionPath.root);
      await tester.sendKeyEvent(LogicalKeyboardKey.numpad7, character: '7');
      await tester.pumpAndSettle();
      expect(controller.selection!.column, DimensionPath.root);
      // Enter toggles the current row's group
      await tester.tap(find.text('10'));
      await tester.pumpAndSettle();
      await key(LogicalKeyboardKey.enter);
      expect(controller.cube.rowExpansion.isExpanded(europe), isTrue);
      expect(find.text('Germany'), findsOneWidget);
    });

    testWidgets('moving the current cell scrolls it into view', (tester) async {
      // 4 data rows of 28 px under 56 px of header do not fit in 120 px
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 120,
              child: CubeView(
                controller: controller,
                aggregates: [sumQty],
                autofocus: true,
              ),
            ),
          ),
        ),
      );
      ScrollController vertical() => tester
          .widget<TableView>(find.byType(TableView))
          .verticalDetails
          .controller!;
      final byA = DimensionPath([const DimensionValue(category, 'A')]);
      controller.selection = CellAddress(row: europe, column: byA); // row 2
      await tester.pumpAndSettle();
      expect(vertical().offset, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(controller.selection!.row.isRoot, isTrue); // the summary row
      expect(vertical().offset, greaterThan(0));
      // a page is the 2 rows that fit under the header: up to Asia (row 1),
      // revealed right under the pinned header band
      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.pumpAndSettle();
      expect(controller.selection!.row.entries.single.value, 'Asia');
      expect(vertical().offset, 28);
    });

    testWidgets('cell taps report the cell', (tester) async {
      // Measured columns are wider than the default 800 px test window.
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      CubeCell? tapped;
      await tester.pumpWidget(
        host(
          CubeView(
            controller: controller,
            aggregates: [sumQty],
            onCellTap: (c) => tapped = c,
          ),
        ),
      );
      await tester.tap(find.text('28'));
      expect(tapped, isNotNull);
      expect(tapped!.factCount, 8);
      expect(tapped!.coordinate.isEmpty, isTrue);
    });

    testWidgets('summaries at the start and hidden', (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final cube = Cube(
        facts: f,
        spec: CubeSpec(
          rows: CubeAxis.of([
            region,
            country,
          ], summaryPosition: SummaryPosition.start),
          columns: CubeAxis.of([
            category,
          ], summaryPosition: SummaryPosition.hidden),
          aggregates: [sumQty],
        ),
      ).toggleRow(europe);
      final c = CubeController(cube);
      await tester.pumpWidget(
        host(CubeView(controller: c, aggregates: [sumQty])),
      );
      // rows: Σ, ∅, Asia, Europe, ∅, Germany, Hungary; columns: ∅, A, B
      expect(cube.layout.rows.entries.first.isSummary, isTrue);
      expect(cube.layout.columns.entries.any((e) => e.isSummary), isFalse);
      expect(find.text('Total'), findsOneWidget); // the row summary only
      expect(find.text('sum of qty'), findsNWidgets(3));
      expect(find.text('28'), findsNothing); // no grand total column
      expect(find.text('15'), findsOneWidget); // Σ × A
      expect(find.text('Germany'), findsOneWidget);
      // sorting rows by a column still works without a summary column
      await tester.tap(find.text('sum of qty').at(1)); // under A
      await tester.pumpAndSettle();
      expect(c.cube.spec.rows.sortAt(0).by, SortBy.aggregate);
      expect(c.cube.layout.rows.entries.first.isSummary, isTrue); // stays first
      // the summary row can be selected and navigated like any other
      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();
      expect(c.selection!.row.isRoot, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(c.selection!.row.isRoot, isFalse);
    });

    testWidgets('subtotals below the group and hidden', (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Cube cube(SubtotalPosition rows, SubtotalPosition columns) =>
          Cube(
                facts: f,
                spec: CubeSpec(
                  rows: CubeAxis.of([region, country], subtotalPosition: rows),
                  columns: CubeAxis.of([
                    category,
                    const ColumnDimension('qty'),
                  ], subtotalPosition: columns),
                  aggregates: [sumQty],
                ),
              )
              .toggleRow(europe)
              .toggleColumn(
                DimensionPath([const DimensionValue(category, 'A')]),
              );
      // below: Europe's row is the last of its group, the L is upside down
      var c = CubeController(
        cube(SubtotalPosition.bottom, SubtotalPosition.bottom),
      );
      await tester.pumpWidget(
        host(CubeView(controller: c, aggregates: [sumQty])),
      );
      final rowsBelow = c.cube.layout.rows.entries.map((e) => e.label).toList();
      expect(
        rowsBelow.indexOf('Europe'),
        greaterThan(rowsBelow.indexOf('Hungary')),
      );
      expect(find.text('Europe'), findsOneWidget); // label drawn once
      expect(find.text('8'), findsOneWidget); // Europe × A: its subtotal
      // hidden: no row for Europe, but its label still spans its children
      // and carries the toggle
      c = CubeController(
        cube(SubtotalPosition.hidden, SubtotalPosition.hidden),
      );
      await tester.pumpWidget(
        host(CubeView(controller: c, aggregates: [sumQty])),
      );
      expect(c.cube.layout.rows.indexOf(europe), -1);
      expect(find.text('Europe'), findsOneWidget);
      expect(find.text('Germany'), findsOneWidget);
      expect(find.text('8'), findsNothing); // no Europe row, no A column
      expect(find.text('A'), findsOneWidget); // hidden column group label
      await tester.tap(toggleIconOf('Europe'));
      await tester.pumpAndSettle();
      expect(c.cube.rowExpansion.isExpanded(europe), isFalse);
      expect(find.text('Germany'), findsNothing);
      expect(c.cube.layout.rows.indexOf(europe), greaterThanOrEqualTo(0));
    });

    testWidgets('several aggregates: one column each under every entry', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(2200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final count = Aggregate.count;
      final c = CubeController(
        Cube(
          facts: f,
          spec: CubeSpec(
            rows: CubeAxis.of([region]),
            columns: CubeAxis.of([category]),
            aggregates: [sumQty, count],
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 2100,
              height: 700,
              child: CubeView(controller: c), // null → both, spec order
            ),
          ),
        ),
      );
      // columns ∅, A, B, Σ → 4 × 2 aggregate labels
      expect(find.text('sum of qty'), findsNWidgets(4));
      expect(find.text('count'), findsNWidgets(4));
      // each entry's label is one merged cell over its two value columns:
      // the label text appears once, and the grid has 1 + 8 columns
      expect(find.text('A'), findsOneWidget);
      int columnCount() =>
          (tester.widget<TableView>(find.byType(TableView)).delegate
                  as TableCellBuilderDelegate)
              .columnCount!;
      expect(columnCount(), 1 + 4 * 2);
      // Europe × A: sum 8, count 2; Σ × Σ: sum 28, count 8
      expect(find.text('8'), findsNWidgets(2)); // Europe×A sum, Σ×Σ count
      expect(find.text('28'), findsOneWidget);
      // sorting by the count under A: only that value column is the key
      await tester.tap(find.text('count').at(1));
      await tester.pumpAndSettle();
      final sort = c.cube.spec.rows.sortAt(0);
      expect(sort.by, SortBy.aggregate);
      expect(sort.aggregate, count);
      expect(
        sort.keyPath,
        DimensionPath([const DimensionValue(category, 'A')]),
      );
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
      // selection names the aggregate; arrows walk the value columns
      await tester.tap(find.text('28'));
      await tester.pumpAndSettle();
      expect(c.selection!.aggregate, sumQty);
      expect(c.selection!.column.isRoot, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(c.selection!.aggregate, count);
      expect(c.selection!.column.isRoot, isTrue); // same entry, next column
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(c.selection!.aggregate, count);
      expect(c.selection!.column.isRoot, isFalse); // B's count
      // a subset in a chosen order
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 2100,
              height: 700,
              child: CubeView(controller: c, aggregates: [count]),
            ),
          ),
        ),
      );
      expect(find.text('sum of qty'), findsNothing);
      expect(find.text('count'), findsNWidgets(4));
      expect(columnCount(), 1 + 4);
    });

    testWidgets('empty axes render a single summary cell', (tester) async {
      controller = CubeController(
        Cube(
          facts: f,
          spec: CubeSpec(aggregates: [sumQty]),
        ),
      );
      await tester.pumpWidget(
        host(CubeView(controller: controller, aggregates: [sumQty])),
      );
      expect(find.text('Total'), findsNWidgets(2));
      expect(find.text('28'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsNothing);
    });

    testWidgets('expanded column groups render merged labels', (tester) async {
      controller = CubeController(
        Cube(
          facts: f,
          spec: CubeSpec(
            rows: CubeAxis.of([region]),
            columns: CubeAxis.of([category, country]),
            aggregates: [sumQty],
          ),
        ).toggleColumn(DimensionPath([const DimensionValue(category, 'A')])),
      );
      await tester.pumpWidget(
        host(CubeView(controller: controller, aggregates: [sumQty])),
      );
      expect(find.text('A'), findsOneWidget);
      expect(find.text('Germany'), findsOneWidget);
      expect(find.text('Iceland'), findsOneWidget);
      // ∅ column (category), ∅ under A (country), ∅ row (region)
      expect(find.text('(empty)'), findsNWidgets(3));
    });
  });

  group('column widths', () {
    /// Whether any Text in the tree was cut with an ellipsis.
    bool anyOverflow(WidgetTester tester) => tester
        .renderObjectList<RenderParagraph>(find.byType(RichText))
        .any((p) => p.didExceedMaxLines);

    /// Width of the box holding [text].
    double cellWidth(WidgetTester tester, String text) => tester
        .getSize(
          find.ancestor(of: find.text(text), matching: find.byType(Container)),
        )
        .width;

    late FactTable big;
    setUpAll(() async {
      final source = ListDataSource(
        columns: ['region', 'amount'],
        rows: const [
          ['Europe', 1234567890123],
          ['A rather long region name', 1],
        ],
        declaredSchema: Schema([
          const ColumnSpec(name: 'region', type: ColumnType.text),
          const ColumnSpec(name: 'amount', type: ColumnType.integer),
        ]),
      );
      big = (await loadFacts(source)).facts;
    });

    final sumAmount = Aggregate.sum(const Measure('amount'));
    CubeView viewOf(FactTable f, Aggregate aggregate, CubeTheme theme) =>
        CubeView(
          controller: CubeController(
            Cube(
              facts: f,
              spec: CubeSpec(
                rows: CubeAxis.of([region]),
                aggregates: [aggregate],
              ),
            ),
          ),
          aggregates: [aggregate],
          theme: theme,
        );

    testWidgets('columns grow to fit their widest text', (tester) async {
      await tester.pumpWidget(host(viewOf(big, sumAmount, const CubeTheme())));
      expect(anyOverflow(tester), isFalse);
      expect(find.text('1,234,567,890,124'), findsOneWidget); // summary
      // The row header is sized by the long region name, the data column
      // by the grand total; both above the minimum.
      expect(
        cellWidth(tester, 'A rather long region name'),
        greaterThan(const CubeTheme().minRowHeaderWidth),
      );
      expect(
        cellWidth(tester, '1,234,567,890,124'),
        greaterThan(const CubeTheme().minColumnWidth),
      );
      // Every data column has the same width (there is only one), and it
      // is the same for the header and the cells.
      expect(
        cellWidth(tester, 'sum of amount'),
        cellWidth(tester, '1,234,567,890,124'),
      );
    });

    testWidgets('measuring merges the ambient DefaultTextStyle', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // theme styles without a size: Text renders them at the ambient 30 px,
      // so measuring at TextPainter's default 14 px would truncate
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DefaultTextStyle(
              style: const TextStyle(fontSize: 30),
              child: SizedBox(
                width: 1500,
                height: 700,
                child: viewOf(
                  big,
                  sumAmount,
                  const CubeTheme(
                    cellTextStyle: TextStyle(fontWeight: FontWeight.bold),
                    headerTextStyle: TextStyle(fontStyle: FontStyle.italic),
                    maxColumnWidth: 2000,
                    maxRowHeaderWidth: 2000,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(anyOverflow(tester), isFalse);
      expect(cellWidth(tester, '1,234,567,890,123'), greaterThan(400));
    });

    testWidgets('widths are clamped to the theme bounds', (tester) async {
      await tester.pumpWidget(
        host(
          viewOf(
            big,
            sumAmount,
            const CubeTheme(
              minColumnWidth: 60,
              maxColumnWidth: 60,
              minRowHeaderWidth: 80,
              maxRowHeaderWidth: 80,
            ),
          ),
        ),
      );
      expect(cellWidth(tester, '1,234,567,890,124'), 60);
      expect(cellWidth(tester, 'A rather long region name'), 80);
      expect(anyOverflow(tester), isTrue);
    });

    testWidgets('the minimum width applies to narrow content', (tester) async {
      await tester.pumpWidget(
        host(viewOf(f, sumQty, const CubeTheme(minColumnWidth: 200))),
      );
      expect(anyOverflow(tester), isFalse);
      expect(cellWidth(tester, '28'), 200);
      expect(cellWidth(tester, 'sum of qty'), 200);
    });

    group('keepColumnWidths', () {
      late FactTable nested;
      setUpAll(() async {
        final source = ListDataSource(
          columns: ['region', 'country', 'amount'],
          rows: const [
            ['Europe', 'A rather long country name', 1],
            ['Asia', 'Japan', 2],
          ],
          declaredSchema: Schema([
            const ColumnSpec(name: 'region', type: ColumnType.text),
            const ColumnSpec(name: 'country', type: ColumnType.text),
            const ColumnSpec(name: 'amount', type: ColumnType.integer),
          ]),
        );
        nested = (await loadFacts(source)).facts;
      });

      /// Expands Europe (the long country name appears in the country
      /// column), collapses it again and returns the country column's
      /// width before, during and after.
      Future<(double, double, double)> run(
        WidgetTester tester, {
        required bool keep,
      }) async {
        final controller = CubeController(
          Cube(
            facts: nested,
            spec: CubeSpec(
              rows: CubeAxis.of([region, country]),
              aggregates: [sumAmount],
            ),
          ),
        );
        await tester.pumpWidget(
          host(
            CubeView(
              controller: controller,
              aggregates: [sumAmount],
              keepColumnWidths: keep,
            ),
          ),
        );
        final before = cellWidth(tester, 'country');
        controller.toggleRow(europe);
        await tester.pump();
        expect(find.text('A rather long country name'), findsOneWidget);
        final during = cellWidth(tester, 'country');
        controller.toggleRow(europe);
        await tester.pump();
        expect(find.text('A rather long country name'), findsNothing);
        return (before, during, cellWidth(tester, 'country'));
      }

      testWidgets('a column keeps its widest width by default', (tester) async {
        final (before, during, after) = await run(tester, keep: true);
        expect(during, greaterThan(before));
        expect(after, during);
      });

      testWidgets('keepColumnWidths: false shrinks again', (tester) async {
        final (before, during, after) = await run(tester, keep: false);
        expect(during, greaterThan(before));
        expect(after, before);
      });
    });
  });
}
