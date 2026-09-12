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

  Widget host({Aggregate? selected, ValueChanged<Aggregate>? onSelected}) =>
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 300,
            child: AggregateEditor(
              controller: controller,
              selected: selected,
              onSelected: onSelected,
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
    Aggregate? switched;
    await tester.pumpWidget(
      host(selected: sumQty, onSelected: (a) => switched = a),
    );
    final chip = find.widgetWithText(InputChip, 'sum of qty');
    expect(tester.widget<InputChip>(chip).selected, isTrue);
    await tester.tap(find.descendant(of: chip, matching: find.byType(Icon)));
    await tester.pumpAndSettle();
    expect(ids(), ['avg(price)']);
    expect(switched, avgPrice);
    final sort = controller.cube.spec.rows.dimensions.single.sort;
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

  testWidgets('selecting a chip reports it', (tester) async {
    Aggregate? selected;
    await tester.pumpWidget(
      host(selected: sumQty, onSelected: (a) => selected = a),
    );
    await tester.tap(find.widgetWithText(InputChip, 'avg of price'));
    await tester.pumpAndSettle();
    expect(selected, avgPrice);
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

  testWidgets('CubeView falls back when its aggregate is gone', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 400,
            child: CubeView(
              controller: controller,
              aggregate: Aggregate.max(qty),
            ),
          ),
        ),
      ),
    );
    // first aggregate shown instead
    expect(find.text('sum of qty'), findsWidgets);
    expect(find.text('3'), findsOneWidget);
  });
}
