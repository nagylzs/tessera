import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
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
      const leaf0 = HeaderArea(
        entryIndex: 0,
        levelStart: 0,
        levelSpan: 2,
        entryStart: 0,
        entrySpan: 1,
        isLabel: true,
      );
      expect(g.areaAt(0, 0), leaf0);
      expect(g.areaAt(1, 0), leaf0);
      const europeLabel = HeaderArea(
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
        const HeaderArea(
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
        const HeaderArea(
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
        const HeaderArea(
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
        host(CubeView(controller: controller, aggregate: sumQty)),
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
            aggregate: sumQty,
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

    testWidgets('expanding a row group through the icon', (tester) async {
      await tester.pumpWidget(
        host(CubeView(controller: controller, aggregate: sumQty)),
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
            aggregate: sumQty,
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
        host(CubeView(controller: controller, aggregate: sumQty)),
      );
      expect(find.byIcon(Icons.arrow_upward), findsNWidgets(3));
      await tester.tap(find.text('region'));
      await tester.pumpAndSettle();
      final sort = controller.cube.spec.rows.dimensions[0].sort;
      expect(sort.by, SortBy.value);
      expect(sort.direction, SortDirection.descending);
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
      expect(controller.cube.layout.rows.entries.map((e) => e.label).take(3), [
        '',
        'Europe',
        'Asia',
      ]);
      await tester.tap(find.text('region'));
      await tester.pumpAndSettle();
      expect(
        controller.cube.spec.rows.dimensions[0].sort.direction,
        SortDirection.ascending,
      );
    });

    testWidgets('tapping the aggregate under a column sorts rows by it', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(CubeView(controller: controller, aggregate: sumQty)),
      );
      // columns: ∅, A, B, Σ → the second "sum of qty" is under A
      await tester.tap(find.text('sum of qty').at(1));
      await tester.pumpAndSettle();
      final byA = DimensionPath([const DimensionValue(category, 'A')]);
      for (final d in controller.cube.spec.rows.dimensions) {
        expect(d.sort.by, SortBy.aggregate);
        expect(d.sort.aggregate, sumQty);
        expect(d.sort.keyPath, byA);
        expect(d.sort.direction, SortDirection.descending);
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
        controller.cube.spec.rows.dimensions[0].sort.direction,
        SortDirection.ascending,
      );
      // sorting by the summary column uses keyPath == null
      await tester.tap(find.text('sum of qty').at(3));
      await tester.pumpAndSettle();
      expect(controller.cube.spec.rows.dimensions[0].sort.keyPath, isNull);
    });

    testWidgets('sortable: false ignores taps', (tester) async {
      await tester.pumpWidget(
        host(
          CubeView(controller: controller, aggregate: sumQty, sortable: false),
        ),
      );
      await tester.tap(find.text('region'));
      await tester.pumpAndSettle();
      expect(
        controller.cube.spec.rows.dimensions[0].sort.direction,
        SortDirection.ascending,
      );
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
            aggregate: sumQty,
            onCellTap: (c) => tapped = c,
          ),
        ),
      );
      await tester.tap(find.text('28'));
      expect(tapped, isNotNull);
      expect(tapped!.factCount, 8);
      expect(tapped!.coordinate.isEmpty, isTrue);
    });

    testWidgets('empty axes render a single summary cell', (tester) async {
      controller = CubeController(
        Cube(
          facts: f,
          spec: CubeSpec(aggregates: [sumQty]),
        ),
      );
      await tester.pumpWidget(
        host(CubeView(controller: controller, aggregate: sumQty)),
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
        host(CubeView(controller: controller, aggregate: sumQty)),
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
          aggregate: aggregate,
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
              aggregate: sumAmount,
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
