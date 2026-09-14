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
  group('expressions and show values as', expressionsAndShowValuesAs);
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
    await tester.tap(
      find.byWidgetPredicate((w) => w is DropdownButtonFormField),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Distinct count').last);
    await tester.pumpAndSettle();
    // one tile per standard dimension; pick region
    await tester.tap(find.widgetWithText(ListTile, 'region').first);
    await tester.pumpAndSettle();
    expect(ids().last, 'distinct(region)');

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate((w) => w is DropdownButtonFormField),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Count of records').last);
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

Future<FactTable> richFacts() async {
  final source = ListDataSource(
    columns: ['region', 'qty', 'price'],
    rows: const [
      ['Europe', 1, 10.0],
      ['Europe', 2, 20.0],
      ['Asia', 5, 50.0],
    ],
    declaredSchema: Schema([
      const ColumnSpec(name: 'region', type: ColumnType.text),
      const ColumnSpec(name: 'qty', type: ColumnType.integer),
      const ColumnSpec(name: 'price', type: ColumnType.number),
    ]),
  );
  return (await loadFacts(source)).facts;
}

void expressionsAndShowValuesAs() {
  late FactTable f;
  late CubeController controller;
  setUpAll(() async => f = await richFacts());

  setUp(() {
    controller = CubeController(
      Cube(
        facts: f,
        spec: CubeSpec(
          rows: CubeAxis(
            dimensions: [
              AxisDimension(
                region,
                sort: AxisSort(by: SortBy.aggregate, aggregate: sumQty),
              ),
            ],
          ),
          aggregates: [sumQty, avgPrice],
        ),
      ),
    );
  });

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

  Future<void> openPicker(WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 3600);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(host());
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
  }

  bool addEnabled(WidgetTester tester) => tester
      .widget<FilledButton>(find.widgetWithText(FilledButton, 'Add aggregate'))
      .enabled;

  testWidgets('a calculated measure under a function', (tester) async {
    await openPicker(tester);
    await tester.tap(find.text('Expression…'));
    await tester.pumpAndSettle();
    expect(find.byType(ExpressionField), findsOneWidget);
    expect(addEnabled(tester), isFalse);
    await tester.enterText(find.byType(ExpressionField), 'qty * price');
    await tester.pumpAndSettle();
    expect(addEnabled(tester), isTrue);
    await tester.enterText(find.byType(ExpressionField), 'qty * region');
    await tester.pumpAndSettle();
    expect(find.text('operand of * must be number, not text'), findsOneWidget);
    expect(addEnabled(tester), isFalse);
    await tester.enterText(find.byType(ExpressionField), 'qty * price');
    await tester.enterText(find.widgetWithText(TextField, 'Label'), 'revenue');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add aggregate'));
    await tester.pumpAndSettle();
    final added = controller.cube.spec.aggregates.last;
    expect(added, isA<SumAggregate>());
    expect((added as SumAggregate).measure, isA<ExpressionMeasure>());
    expect(added.measure.label, 'revenue');
    expect(added.id, 'sum(qty * price)');
    expect(find.widgetWithText(InputChip, 'sum of revenue'), findsOneWidget);
    expect(controller.cube.layout.cellAt(2, 0).aggregate(added), 300.0);
  });

  testWidgets('a cell formula', (tester) async {
    await openPicker(tester);
    await tester.tap(
      find.byWidgetPredicate((w) => w is DropdownButtonFormField),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Formula').last);
    await tester.tap(find.text('Formula').last);
    await tester.pumpAndSettle();
    expect(find.byType(ExpressionField), findsOneWidget);
    await tester.enterText(
      find.byType(ExpressionField),
      'sum(price) / sum(qty)',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Label'), 'unit');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add aggregate'));
    await tester.pumpAndSettle();
    final added = controller.cube.spec.aggregates.last;
    expect(
      added,
      isA<ExpressionAggregate>().having((a) => a.label, 'label', 'unit'),
    );
    expect(controller.cube.layout.cellAt(2, 0).aggregate(added), 10.0);
    // the same formula again is refused as already in use
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate((w) => w is DropdownButtonFormField),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Formula').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(ExpressionField),
      'sum(price) / sum(qty)',
    );
    await tester.pumpAndSettle();
    expect(addEnabled(tester), isFalse);
    expect(find.text('already in use'), findsOneWidget);
  });

  testWidgets('show values as wraps and unwraps a chip', (tester) async {
    final selection = <List<Aggregate>>[];
    // the owner keeps the selection the editor reports (same set instance)
    final selected = <Aggregate>{sumQty};
    tester.view.physicalSize = const Size(2400, 3600);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      host(
        selected: selected,
        onSelected: (list) {
          selection.add(list);
          selected
            ..clear()
            ..addAll(list);
        },
      ),
    );
    await tester.longPress(find.widgetWithText(InputChip, 'sum of qty'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show values as'));
    await tester.pumpAndSettle();
    expect(find.text('Plain value'), findsOneWidget);
    expect(find.text('% of row total'), findsOneWidget);
    await tester.tap(find.text('% of column total'));
    await tester.pumpAndSettle();
    final wrapped = controller.cube.spec.aggregates.first;
    expect(wrapped, Aggregate.percentOf(sumQty, TotalOf.column));
    expect(
      find.widgetWithText(InputChip, 'sum of qty % of column total'),
      findsOneWidget,
    );
    // the sort and the selection follow
    expect(controller.cube.spec.rows.dimensions.first.sort!.aggregate, wrapped);
    expect(selection.last, [wrapped]);
    expect(
      controller.cube.layout.rows.entries.map(
        (e) => e.path.isRoot ? 'T' : e.value,
      ),
      ['Europe', 'Asia', 'T'],
    );
    // a second choice replaces the wrapper rather than nesting
    await tester.longPress(find.byType(InputChip).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show values as'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rank along rows'));
    await tester.pumpAndSettle();
    expect(
      controller.cube.spec.aggregates.first,
      Aggregate.rank(sumQty, axis: AxisSide.rows),
    );
    // and back to the plain value
    await tester.longPress(find.byType(InputChip).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show values as'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plain value'));
    await tester.pumpAndSettle();
    expect(controller.cube.spec.aggregates.first, sumQty);
    expect(selection.last, [sumQty]);
  });

  test('ValueDisplay round-trips and names are distinct in every locale', () {
    for (final d in ValueDisplay.values) {
      final a = d.apply(sumQty);
      expect(ValueDisplay.of(a), d, reason: d.name);
      expect(ValueDisplay.plainOf(a), sumQty);
      expect(d.apply(a), a, reason: 'idempotent ${d.name}');
    }
    expect(
      ValueDisplay.of(
        Aggregate.differenceFrom(
          sumQty,
          axis: AxisSide.rows,
          item: BaseItem.next,
        ),
      ),
      isNull,
    );
    expect(
      ValueDisplay.of(
        Aggregate.rank(sumQty, axis: AxisSide.rows, ascending: true),
      ),
      isNull,
    );
    expect(
      ValueDisplay.percentOfRow.apply(
        Aggregate.rank(sumQty, axis: AxisSide.rows),
      ),
      Aggregate.percentOf(sumQty, TotalOf.row),
    );
    for (final code in TesseraStrings.supportedLanguages) {
      final s = TesseraStrings.forLanguage(code)!;
      final names = ValueDisplay.values.map(s.valueDisplayName).toSet();
      expect(names.length, ValueDisplay.values.length, reason: code);
      expect(s.showValuesAs, isNotEmpty);
      expect(s.formula, isNotEmpty);
      expect(s.labelField, isNotEmpty);
    }
  });
}
