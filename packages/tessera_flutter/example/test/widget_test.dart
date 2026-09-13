import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tessera_flutter/tessera_flutter.dart';
import 'package:tessera_example/main.dart';
import 'package:tessera_example/simple/sales_page.dart';
import 'package:tessera_example/common/schema_page.dart';

/// Pumps until [finder] matches (asset loading is real I/O, so this runs
/// under [WidgetTester.runAsync]).
Future<void> waitFor(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 50 && finder.evaluate().isEmpty; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();
  }
  expect(finder, findsWidgets);
}

void main() {
  testWidgets('loads sales.csv and shows the cube', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(const TesseraExampleApp());
      expect(find.text('Tessera examples'), findsOneWidget);
      await tester.tap(find.text('Simple pivot'));
      // Not pumpAndSettle: the page shows a spinner while loading.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Tessera — sales.csv'), findsOneWidget);
      await waitFor(tester, find.textContaining('1000 facts, 11 columns'));
    });
    expect(find.text('Europe'), findsOneWidget);
    expect(find.text('Total'), findsNWidgets(2));
    expect(find.widgetWithText(InputChip, 'sum of total'), findsOneWidget);
  });

  testWidgets('schema page: a label edit applies on back without re-import', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(const TesseraExampleApp());
      await tester.tap(find.text('Simple pivot'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await waitFor(tester, find.textContaining('1000 facts, 11 columns'));
      expect(find.widgetWithText(InputChip, 'date year'), findsOneWidget);
      await tester.tap(find.byTooltip('Schema…'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('label-date')), 'dátum');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
    });
    // chips and the grid's titles follow the new label immediately
    expect(find.widgetWithText(InputChip, 'dátum year'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'dátum quarter'), findsOneWidget);
    expect(find.text('dátum year'), findsNWidgets(2)); // chip + corner title
    expect(find.text('date year'), findsNothing);
    // no re-import happened: the report line is the original one
    expect(find.textContaining('1000 facts, 11 columns'), findsOneWidget);
  });

  testWidgets(
    'schema page: exclude a column and change a type, then re-import',
    (tester) async {
      // The schema list is lazy; make the surface tall enough for all rows.
      tester.view.physicalSize = const Size(1400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.runAsync(() async {
        await tester.pumpWidget(const TesseraExampleApp());
        await tester.tap(find.text('Simple pivot'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await waitFor(tester, find.textContaining('1000 facts, 11 columns'));
        await tester.tap(find.byTooltip('Schema…'));
        await tester.pumpAndSettle();
        expect(find.byType(SchemaPage), findsOneWidget);
        expect(find.byType(Switch), findsNWidgets(11));
        // samples from the first rows are shown
        expect(find.textContaining('Europe'), findsWidgets);

        // exclude "id"
        await tester.tap(find.byType(Switch).first);
        await tester.pumpAndSettle();
        // make "quantity" text
        await tester.tap(find.byKey(const ValueKey('type-quantity')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('text').last);
        await tester.pumpAndSettle();
        // give "total" a label
        await tester.enterText(
          find.byKey(const ValueKey('label-total')),
          'Revenue',
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Apply'));
        await tester.pumpAndSettle();
        await waitFor(tester, find.textContaining('1000 facts, 10 columns'));
      });
      final page = tester.state<State<SalesPage>>(find.byType(SalesPage));
      expect(page, isNotNull);
      // the cube survived the re-import with the same axes
      expect(find.widgetWithText(InputChip, 'region'), findsOneWidget);
      expect(find.widgetWithText(InputChip, 'date year'), findsOneWidget);
      expect(find.widgetWithText(InputChip, 'sum of Revenue'), findsOneWidget);
      // quantity is text now, so it is offered as a plain dimension but not as a measure
      await tester.tap(
        find.descendant(
          of: find.byType(AggregateEditor),
          matching: find.byIcon(Icons.add),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'quantity'), findsNothing);
      expect(find.widgetWithText(ListTile, 'id'), findsNothing);
      expect(find.widgetWithText(ListTile, 'Revenue'), findsWidgets);
    },
  );
}
