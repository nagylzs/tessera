import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tessera_flutter/tessera_flutter.dart';

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
