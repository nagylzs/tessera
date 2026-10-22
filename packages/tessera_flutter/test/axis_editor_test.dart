import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tessera_flutter/tessera_flutter.dart';

const region = ColumnDimension('region');
const country = ColumnDimension('country');
const category = ColumnDimension('category');
const qty = Measure('qty');
final qtySum = Aggregate.sum(qty);

Future<FactTable> facts() async {
  final source = ListDataSource(
    columns: ['region', 'country', 'category', 'qty'],
    rows: const [
      ['Europe', 'Germany', 'A', 1],
      ['Asia', 'Japan', 'B', 2],
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

List<String> ids(CubeAxis axis) => [
  for (final d in axis.dimensions) d.dimension.id,
];

void main() {
  late FactTable f;
  late CubeController controller;
  setUpAll(() async => f = await facts());

  setUp(() {
    controller = CubeController(
      Cube(
        facts: f,
        spec: CubeSpec(
          rows: CubeAxis(
            dimensions: const [
              AxisDimension(
                region,
                sort: AxisSort(direction: SortDirection.descending),
              ),
              AxisDimension(country),
            ],
          ),
          columns: CubeAxis.of([category]),
          aggregates: [Aggregate.sum(qty)],
        ),
      ),
    );
  });

  Widget host() => MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 900,
        height: 400,
        child: Column(
          children: [
            AxisEditor(controller: controller, side: AxisSide.rows),
            const SizedBox(height: 40),
            AxisEditor(controller: controller, side: AxisSide.columns),
          ],
        ),
      ),
    ),
  );

  /// Drags the chip labelled [chip] and drops it at the centre of [target].
  Future<void> dragTo(WidgetTester tester, String chip, Finder target) async {
    final from = tester.getCenter(find.widgetWithText(InputChip, chip).first);
    final to = tester.getCenter(target);
    final gesture = await tester.startGesture(from);
    await tester.pump();
    await gesture.moveTo(from + const Offset(20, 0));
    await tester.pump();
    await gesture.moveTo(to);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('the caption menu sets the summary position', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('Rows'));
    await tester.pumpAndSettle();
    expect(find.text('Totals at the end'), findsOneWidget);
    await tester.tap(find.text('Totals at the start'));
    await tester.pumpAndSettle();
    expect(controller.cube.spec.rows.summaryPosition, SummaryPosition.start);
    expect(controller.cube.spec.columns.summaryPosition, SummaryPosition.end);
    await tester.tap(find.text('Columns'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hide totals'));
    await tester.pumpAndSettle();
    expect(
      controller.cube.spec.columns.summaryPosition,
      SummaryPosition.hidden,
    );
    expect(
      controller.cube.layout.columns.entries.any((e) => e.isSummary),
      isFalse,
    );
    // subtotals: the second group of the same menu
    await tester.tap(find.text('Rows'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Subtotals below the group'));
    await tester.pumpAndSettle();
    expect(controller.cube.spec.rows.subtotalPosition, SubtotalPosition.bottom);
    expect(controller.cube.spec.rows.summaryPosition, SummaryPosition.start);
    // the column axis speaks of left/right
    await tester.tap(find.text('Columns'));
    await tester.pumpAndSettle();
    expect(find.text('Subtotals below the group'), findsNothing);
    await tester.tap(find.text('Subtotals right of the group'));
    await tester.pumpAndSettle();
    expect(
      controller.cube.spec.columns.subtotalPosition,
      SubtotalPosition.bottom,
    );
    // dimensions and sorts untouched
    expect(controller.cube.spec.rows.dimensions.length, 2);
    expect(
      controller.cube.spec.rows.dimensions[0].sort!.direction,
      SortDirection.descending,
    );
  });

  testWidgets('shows captions and one chip per dimension', (tester) async {
    await tester.pumpWidget(host());
    expect(find.text('Rows'), findsOneWidget);
    expect(find.text('Columns'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'region'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'country'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'category'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsNWidgets(2));
  });

  testWidgets('deleting a chip removes the dimension', (tester) async {
    await tester.pumpWidget(host());
    final deleteIcon = find.descendant(
      of: find.widgetWithText(InputChip, 'country'),
      matching: find.byType(Icon),
    );
    await tester.tap(deleteIcon);
    await tester.pumpAndSettle();
    expect(ids(controller.cube.spec.rows), ['region']);
    expect(find.widgetWithText(InputChip, 'country'), findsNothing);
  });

  testWidgets('empty axis shows the hint', (tester) async {
    controller.updateSpec(
      controller.cube.spec.copyWith(columns: const CubeAxis()),
    );
    await tester.pumpWidget(host());
    expect(find.text('Drop dimensions here'), findsOneWidget);
  });

  testWidgets('dragging between axes moves the dimension and keeps its sort', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await dragTo(tester, 'region', find.byType(AxisEditor).at(1));
    expect(ids(controller.cube.spec.rows), ['country']);
    expect(ids(controller.cube.spec.columns), ['category', 'region']);
    expect(
      controller.cube.spec.columns.dimensions.last.sort!.direction,
      SortDirection.descending,
    );
  });

  testWidgets('dropping on a chip inserts before it', (tester) async {
    await tester.pumpWidget(host());
    await dragTo(tester, 'category', find.widgetWithText(InputChip, 'country'));
    expect(ids(controller.cube.spec.rows), ['region', 'category', 'country']);
    expect(ids(controller.cube.spec.columns), isEmpty);
  });

  testWidgets('reordering within an axis', (tester) async {
    await tester.pumpWidget(host());
    await dragTo(tester, 'country', find.widgetWithText(InputChip, 'region'));
    expect(ids(controller.cube.spec.rows), ['country', 'region']);
    // and back: drop region on empty space → appended after country → same
    await dragTo(tester, 'region', find.widgetWithText(InputChip, 'country'));
    expect(ids(controller.cube.spec.rows), ['region', 'country']);
  });

  testWidgets('the picker adds a dimension, disables used ones, filters', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();
    expect(find.text('Add dimension'), findsOneWidget);
    // all four columns are listed; three are in use
    expect(find.text('already in use'), findsNWidgets(3));
    final used = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'category'),
    );
    expect(used.enabled, isFalse);
    await tester.enterText(find.byType(TextField), 'qt');
    await tester.pumpAndSettle();
    // qty, and the expression entry, which stays whatever the search
    expect(find.byType(ListTile), findsNWidgets(2));
    await tester.tap(find.widgetWithText(ListTile, 'qty').first);
    await tester.pumpAndSettle();
    expect(ids(controller.cube.spec.rows), ['region', 'country', 'qty']);
    expect(find.text('Add dimension'), findsNothing);
  });

  testWidgets('custom available list and label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AxisEditor(
            controller: controller,
            side: AxisSide.columns,
            label: 'Oszlopok',
            available: const [DatePartDimension('date', DatePart.month)],
          ),
        ),
      ),
    );
    expect(find.text('Oszlopok'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    // the month, and the expression entry
    expect(find.byType(ListTile), findsNWidgets(2));
    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();
    expect(ids(controller.cube.spec.columns), ['category', 'date.month']);
  });

  group('computed dimensions', () {
    bool addEnabled(WidgetTester tester) => tester
        .widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Add dimension'),
        )
        .enabled;

    Future<void> tapAdd(WidgetTester tester) async {
      final button = find.widgetWithText(FilledButton, 'Add dimension');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    Future<void> openExpression(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.add).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Expression…'));
      await tester.pumpAndSettle();
    }

    testWidgets('an expression with a label joins the axis', (tester) async {
      await tester.pumpWidget(host());
      await openExpression(tester);
      expect(find.byType(ExpressionField), findsOneWidget);
      expect(addEnabled(tester), isFalse);
      await tester.enterText(find.byType(ExpressionField), 'year(qty)');
      await tester.pumpAndSettle();
      expect(
        find.text('argument 1 of year must be date, not number'),
        findsOneWidget,
      );
      expect(addEnabled(tester), isFalse);
      await tester.enterText(
        find.byType(ExpressionField),
        'if(qty > 1, "big", "small")',
      );
      await tester.enterText(find.widgetWithText(TextField, 'Label'), 'size');
      await tester.pumpAndSettle();
      expect(addEnabled(tester), isTrue);
      await tapAdd(tester);
      final added = controller.cube.spec.columns.dimensions.last.dimension;
      expect(
        added,
        isA<ExpressionDimension>()
            .having((d) => d.source, 'source', 'if(qty > 1, "big", "small")')
            .having((d) => d.label, 'label', 'size'),
      );
      expect(find.widgetWithText(InputChip, 'size'), findsOneWidget);
      // grouped like a column: the facts split into "big" and "small"
      final cube = Cube(
        facts: f,
        spec: CubeSpec(rows: CubeAxis.of([added]), aggregates: [qtySum]),
      );
      expect(
        [
          for (final e in cube.layout.rows.entries)
            if (!e.isSummary) (e.label, e.factCount),
        ],
        [('big', 1), ('small', 1)],
      );
    });

    testWidgets('without a label the chip shows the expression', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      await openExpression(tester);
      await tester.enterText(
        find.byType(ExpressionField),
        'floor(qty / 10) * 10',
      );
      await tester.pumpAndSettle();
      await tapAdd(tester);
      expect(
        find.widgetWithText(InputChip, 'floor(qty / 10) * 10'),
        findsOneWidget,
      );
    });

    testWidgets('the same expression twice is already in use', (tester) async {
      await tester.pumpWidget(host());
      await openExpression(tester);
      await tester.enterText(find.byType(ExpressionField), 'qty % 2');
      await tester.pumpAndSettle();
      await tapAdd(tester);
      await openExpression(tester);
      await tester.enterText(find.byType(ExpressionField), 'qty % 2');
      await tester.enterText(find.widgetWithText(TextField, 'Label'), 'odd');
      await tester.pumpAndSettle();
      expect(addEnabled(tester), isFalse);
      // whatever the label: the id is the expression
      expect(find.text('already in use'), findsOneWidget);
      // the entry swaps the form back for the list
      await tester.tap(find.text('Expression…'));
      await tester.pumpAndSettle();
      expect(find.byType(ExpressionField), findsNothing);
      expect(find.widgetWithText(ListTile, 'region'), findsOneWidget);
    });

    testWidgets('no expression entry without facts', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showDimensionPicker(context, dimensions: const [region]),
              child: const Text('pick'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('pick'));
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsOneWidget);
      expect(find.text('Expression…'), findsNothing);
    });
  });
}
