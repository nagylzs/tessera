import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tessera_flutter/tessera_flutter.dart';

const region = ColumnDimension('region');
const qty = Measure('qty');
const price = Measure('price');
final sumQty = Aggregate.sum(qty);
final avgPrice = Aggregate.average(price);

Future<FactTable> facts() async {
  final source = ListDataSource(
    columns: ['region', 'qty', 'price'],
    rows: const [
      ['Europe', 1, 10.0],
      ['Asia', 2, 20.0],
    ],
    declaredSchema: Schema([
      const ColumnSpec(name: 'region', type: ColumnType.text),
      const ColumnSpec(name: 'qty', type: ColumnType.integer),
      const ColumnSpec(name: 'price', type: ColumnType.number),
    ]),
  );
  return (await loadFacts(source)).facts;
}

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
            dimensions: [
              AxisDimension(
                region,
                sort: AxisSort(
                  by: SortBy.aggregate,
                  aggregate: sumQty,
                  direction: SortDirection.descending,
                ),
              ),
            ],
          ),
          aggregates: [sumQty, avgPrice],
        ),
      ),
    );
  });

  List<String> ids() => [for (final a in controller.cube.spec.aggregates) a.id];

  Widget host({
    Set<Aggregate>? selected,
    ValueChanged<List<Aggregate>>? onSelected,
  }) => MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 800,
        height: 300,
        child: AggregateEditor(
          controller: controller,
          selected: selected,
          onSelectedChanged: onSelected,
        ),
      ),
    ),
  );

  testWidgets('shows one chip per aggregate', (tester) async {
    await tester.pumpWidget(host());
    expect(find.text('Values'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'sum of qty'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'avg of price'), findsOneWidget);
  });

  testWidgets('removing resets sorts that used it; the last one cannot go', (
    tester,
  ) async {
    List<Aggregate>? switched;
    await tester.pumpWidget(
      host(selected: {sumQty}, onSelected: (a) => switched = a),
    );
    final chip = find.widgetWithText(InputChip, 'sum of qty');
    expect(tester.widget<InputChip>(chip).selected, isTrue);
    await tester.tap(find.descendant(of: chip, matching: find.byType(Icon)));
    await tester.pumpAndSettle();
    expect(ids(), ['avg(price)']);
    expect(switched, [avgPrice]);
    final sort = controller.cube.spec.rows.dimensions.single.sort!;
    expect(sort.by, SortBy.value);
    expect(sort.direction, SortDirection.descending);
    // the cube still lays out
    expect(controller.cube.layout.rows.length, 3);
    // the remaining chip has no delete icon
    final last = tester.widget<InputChip>(
      find.widgetWithText(InputChip, 'avg of price'),
    );
    expect(last.onDeleted, isNull);
  });

  testWidgets('chips toggle the selection, never below one', (tester) async {
    List<Aggregate>? selected;
    await tester.pumpWidget(
      host(selected: {sumQty}, onSelected: (a) => selected = a),
    );
    // adding: reported in the spec's order
    await tester.tap(find.widgetWithText(InputChip, 'avg of price'));
    await tester.pumpAndSettle();
    expect(selected, [sumQty, avgPrice]);
    // the only selected one cannot be deselected
    selected = null;
    await tester.tap(find.widgetWithText(InputChip, 'sum of qty'));
    await tester.pumpAndSettle();
    expect(selected, isNull);
    // with two selected, deselecting one works
    await tester.pumpWidget(
      host(selected: {sumQty, avgPrice}, onSelected: (a) => selected = a),
    );
    await tester.tap(find.widgetWithText(InputChip, 'sum of qty'));
    await tester.pumpAndSettle();
    expect(selected, [avgPrice]);
  });

  testWidgets('the picker adds a measure aggregate and disables used ones', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('Add aggregate'), findsOneWidget);
    // default function is Sum: qty is used, price is free
    expect(find.text('already in use'), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'price').first);
    await tester.pumpAndSettle();
    expect(ids(), ['sum(qty)', 'avg(price)', 'sum(price)']);
  });

  testWidgets('the picker offers count and distinct count', (tester) async {
    // 11 kinds do not fit the default 600 px dropdown menu
    tester.view.physicalSize = const Size(2400, 3600);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(host());
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<AggregateKind>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Distinct count').last);
    await tester.pumpAndSettle();
    // one tile per standard dimension; pick region
    await tester.tap(find.widgetWithText(ListTile, 'region').first);
    await tester.pumpAndSettle();
    expect(ids().last, 'distinct(region)');

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<AggregateKind>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Count of facts').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    expect(ids().last, 'count');
  });

  test('AggregateKind builds the right aggregates', () {
    expect(AggregateKind.sum.build(measure: qty), sumQty);
    expect(AggregateKind.average.build(measure: price), avgPrice);
    expect(AggregateKind.min.build(measure: qty).id, 'min(qty)');
    expect(AggregateKind.max.build(measure: qty).id, 'max(qty)');
    expect(AggregateKind.countNonNull.build(measure: qty).id, 'count(qty)');
    expect(
      AggregateKind.distinctCount.build(dimension: region).id,
      'distinct(region)',
    );
    expect(AggregateKind.count.build(), Aggregate.count);
    expect(AggregateKind.count.needsMeasure, isFalse);
    expect(AggregateKind.distinctCount.needsDimension, isTrue);
    expect(standardMeasures(f).map((m) => m.id), ['qty', 'price']);
  });

  testWidgets('CubeView skips aggregates the spec lacks', (tester) async {
    Widget host(List<Aggregate>? aggregates) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 800,
          height: 400,
          child: CubeView(controller: controller, aggregates: aggregates),
        ),
      ),
    );
    // an unknown one is dropped, the known one stays
    await tester.pumpWidget(host([Aggregate.max(qty), avgPrice]));
    expect(find.text('sum of qty'), findsNothing);
    expect(find.text('avg of price'), findsWidgets);
    expect(find.text('max of qty'), findsNothing);
    // only unknown ones: blank cells, the header row stays
    await tester.pumpWidget(host([Aggregate.max(qty)]));
    expect(find.text('sum of qty'), findsNothing);
    expect(find.text('3'), findsNothing);
    // null: every aggregate of the spec, side by side
    await tester.pumpWidget(host(null));
    expect(find.text('sum of qty'), findsWidgets);
    expect(find.text('avg of price'), findsWidgets);
  });
}
