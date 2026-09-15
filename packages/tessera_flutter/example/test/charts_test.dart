import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tessera_example/charts/chart_panel.dart';
import 'package:tessera_example/charts/chart_widgets.dart';
import 'package:tessera_flutter/tessera_flutter.dart';

/// region, country, date, qty, price
const _rows = <List<Object?>>[
  ['Europe', 'Germany', '2024-01-05', 1, 10.0],
  ['Europe', 'Hungary', '2024-03-05', 2, 20.0],
  ['Europe', 'Germany', '2025-01-05', 4, 30.0],
  ['Asia', 'Japan', '2024-06-05', 8, 40.0],
  ['Asia', 'Japan', '2025-06-05', 16, 50.0],
  [null, 'Iceland', '2024-02-01', 32, 60.0],
];

const region = ColumnDimension('region');
const country = ColumnDimension('country');
const year = DatePartDimension('date', DatePart.year);
const month = DatePartDimension('date', DatePart.month);
final sumQty = Aggregate.sum(const Measure('qty'));
final avgPrice = Aggregate.average(const Measure('price'));

Future<FactTable> facts() async {
  final source = ListDataSource(
    columns: ['region', 'country', 'date', 'qty', 'price'],
    rows: _rows,
    declaredSchema: Schema([
      const ColumnSpec(name: 'region', type: ColumnType.text),
      const ColumnSpec(name: 'country', type: ColumnType.text),
      const ColumnSpec(name: 'date', type: ColumnType.date),
      const ColumnSpec(name: 'qty', type: ColumnType.integer),
      const ColumnSpec(name: 'price', type: ColumnType.number),
    ]),
  );
  return (await loadFacts(source)).facts;
}

Widget app(Widget child) => MaterialApp(
  localizationsDelegates: const [TesseraLocalizations.delegate],
  supportedLocales: TesseraLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  late FactTable f;
  late CubeController controller;

  setUpAll(() async {
    f = await facts();
  });

  setUp(() {
    controller = CubeController(
      Cube(
        facts: f,
        spec: CubeSpec(
          rows: CubeAxis.of([region, country]),
          columns: CubeAxis.of([year]),
          aggregates: [sumQty, avgPrice],
        ),
      ),
    );
  });

  Widget panel() => app(
    ChartPanel(
      controller: controller,
      dimensions: const [region, country, year, month],
    ),
  );

  Future<void> choose(WidgetTester tester, String chip) async {
    await tester.tap(find.widgetWithText(ChoiceChip, chip));
    await tester.pumpAndSettle();
  }

  testWidgets('every chart type renders from every source', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(panel());
    await tester.pumpAndSettle();
    for (final source in ChartSource.values) {
      await choose(tester, source.label);
      for (final type in ChartType.values) {
        await choose(tester, type.label);
        expect(tester.takeException(), isNull, reason: '$source $type');
        final chart = switch (type) {
          ChartType.bar || ChartType.stacked => find.byType(BarChart),
          ChartType.line => find.byType(LineChart),
          ChartType.pie => find.byType(PieChart),
          ChartType.scatter => find.byType(ScatterChart),
        };
        expect(chart, findsOneWidget, reason: '$source $type');
        final producer = type == ChartType.scatter
            ? 'ScatterData'
            : 'ChartData';
        final method = switch (source) {
          ChartSource.layout => 'fromLayout',
          ChartSource.facts => 'fromFacts',
          ChartSource.cell => 'fromCell',
        };
        expect(
          find.textContaining('$producer.$method'),
          findsOneWidget,
          reason: '$source $type',
        );
      }
    }
  });

  testWidgets('the chart follows the controller', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(panel());
    await tester.pumpAndSettle();
    // leaves: (empty), Asia, Europe × 2024, 2025
    expect(find.textContaining('3 categories × 2 series'), findsOneWidget);
    controller.cube = controller.cube.toggleRow(
      const DimensionPath([DimensionValue(region, 'Europe')]),
    );
    await tester.pumpAndSettle();
    // Europe is expanded: its subtotal is skipped, Germany + Hungary appear
    expect(find.textContaining('4 categories × 2 series'), findsOneWidget);
  });

  testWidgets('cell mode pins the selected cell\'s dimensions', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(panel());
    await tester.pumpAndSettle();
    await choose(tester, 'Cell');
    expect(
      find.textContaining('grand total (no cell selected)'),
      findsOneWidget,
    );

    controller.selection = const CellAddress(
      row: DimensionPath([DimensionValue(region, 'Europe')]),
      column: DimensionPath([DimensionValue(year, 2024)]),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('region = Europe, date year = 2024'),
      findsOneWidget,
    );
    // region was the default category and is now pinned → country takes over
    final category = tester.widget<DropdownMenu<Dimension?>>(
      find.byWidgetPredicate(
        (w) =>
            w is DropdownMenu<Dimension?> &&
            (w.label as Text).data == 'Category',
      ),
    );
    expect(category.initialSelection, country);
    final enabled = {
      for (final e in category.dropdownMenuEntries) e.value: e.enabled,
    };
    expect(enabled[region], isFalse);
    expect(enabled[year], isFalse);
    expect(enabled[country], isTrue);
    expect(enabled[month], isTrue); // a finer date part is still useful
    expect(find.textContaining('2 categories × 1 series'), findsOneWidget);
  });

  testWidgets('per-fact scatter of the current cell', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(panel());
    await tester.pumpAndSettle();
    await choose(tester, 'Scatter');
    await choose(tester, 'Cell');
    controller.selection = const CellAddress(
      row: DimensionPath([DimensionValue(region, 'Europe')]),
      column: DimensionPath.root,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('ScatterData.fromCell'), findsOneWidget);
    await tester.tap(find.byType(Checkbox).last); // "Per fact"
    await tester.pumpAndSettle();
    expect(find.textContaining('ScatterData.ofFacts'), findsOneWidget);
    expect(find.textContaining('3 facts'), findsOneWidget);
    expect(find.byType(ScatterChart), findsOneWidget);
  });

  testWidgets('scatter from the layout needs two aggregates', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    controller.cube = controller.cube.copyWith(
      spec: controller.cube.spec.copyWith(aggregates: [sumQty]),
    );
    await tester.pumpWidget(panel());
    await tester.pumpAndSettle();
    await choose(tester, 'Scatter');
    expect(find.textContaining('needs two aggregates'), findsOneWidget);
    expect(find.byType(ScatterChart), findsNothing);
  });

  test('line axis kind follows the category values', () {
    final byYear = ChartData.fromFacts(f, category: year, aggregate: sumQty);
    expect(LineAxis.of(byYear), LineAxis.time);
    final byQty = ChartData.fromFacts(
      f,
      category: const ColumnDimension('qty'),
      aggregate: sumQty,
    );
    expect(LineAxis.of(byQty), LineAxis.numeric);
    final byRegion = ChartData.fromFacts(
      f,
      category: region,
      aggregate: sumQty,
    );
    expect(LineAxis.of(byRegion), LineAxis.categorical);
    expect(LineAxis.of(byRegion.withoutEmpty()), LineAxis.categorical);
  });

  test('shortNumber', () {
    expect(shortNumber(0), '0');
    expect(shortNumber(12.5), '12.5');
    expect(shortNumber(1500), '1.5k');
    expect(shortNumber(25000), '25k');
    expect(shortNumber(-2500000), '-2.5M');
  });
}
