import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tessera/tessera.dart';

Future<FactTable> facts() async {
  final source = ListDataSource(
    columns: ['region', 'date', 'total'],
    rows: const [
      ['Europe', '2025-01-05', 1],
    ],
    declaredSchema: Schema([
      const ColumnSpec(name: 'region', type: ColumnType.text, label: 'Region'),
      const ColumnSpec(name: 'date', type: ColumnType.date, label: 'Sold on'),
      const ColumnSpec(
        name: 'total',
        type: ColumnType.integer,
        label: 'Revenue',
      ),
    ]),
  );
  return (await loadFacts(source)).facts;
}

void main() {
  late FactTable f;
  setUpAll(() async => f = await facts());

  test('dimensions follow column labels unless given one', () {
    const region = ColumnDimension('region');
    expect(region.label, 'region');
    expect(region.labelFor(f), 'Region');
    expect(const ColumnDimension('region', label: 'Area').labelFor(f), 'Area');
    expect(const ColumnDimension('missing').labelFor(f), 'missing');
    const month = DatePartDimension('date', DatePart.month);
    expect(month.label, 'date month');
    expect(month.labelFor(f), 'Sold on month');
    expect(
      const DatePartDimension('nope', DatePart.year).labelFor(f),
      'nope year',
    );
    final mapped = MappedDimension(
      id: 'm',
      sourceColumn: 'region',
      map: (v) => v,
    );
    expect(mapped.labelFor(f), 'm');
  });

  test('measures and aggregates follow column labels', () {
    const total = Measure('total');
    expect(total.label, 'total');
    expect(total.labelFor(f), 'Revenue');
    expect(const Measure('total', label: 'Sales').labelFor(f), 'Sales');
    expect(Aggregate.sum(total).label, 'sum of total');
    expect(Aggregate.sum(total).labelFor(f), 'sum of Revenue');
    expect(Aggregate.average(const Measure('gone')).labelFor(f), 'avg of gone');
    expect(
      Aggregate.distinctCount(const ColumnDimension('region')).labelFor(f),
      'distinct Region',
    );
    expect(Aggregate.count.labelFor(f), 'count');
    expect(f.findColumn('total')!.label, 'Revenue');
    expect(f.findColumn('nope'), isNull);
  });

  testWidgets('widgets show the resolved labels', (tester) async {
    final sumTotal = Aggregate.sum(const Measure('total'));
    final controller = CubeController(
      Cube(
        facts: f,
        spec: CubeSpec(
          rows: CubeAxis.of([const ColumnDimension('region')]),
          columns: CubeAxis.of([
            const DatePartDimension('date', DatePart.year),
          ]),
          aggregates: [sumTotal],
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              AxisEditor(controller: controller, side: AxisSide.rows),
              AxisEditor(controller: controller, side: AxisSide.columns),
              AggregateEditor(controller: controller),
              Expanded(
                child: CubeView(controller: controller, aggregate: sumTotal),
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.widgetWithText(InputChip, 'Region'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'Sold on year'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'sum of Revenue'), findsOneWidget);
    // corner titles and the aggregate header row in the grid
    expect(find.text('Region'), findsNWidgets(2));
    expect(find.text('Sold on year'), findsNWidgets(2));
    expect(find.text('sum of Revenue'), findsNWidgets(3)); // chip + 2 columns
    expect(find.text('sum of total'), findsNothing);
  });
}
