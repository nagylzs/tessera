import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tessera_flutter/tessera_flutter.dart';

const region = ColumnDimension('region');
const month = DatePartDimension('date', DatePart.month);
const total = Measure('total');

Future<FactTable> facts() async {
  final source = ListDataSource(
    columns: ['region', 'date', 'total'],
    rows: const [
      ['Europe', '2025-01-05', 1],
    ],
    declaredSchema: Schema([
      const ColumnSpec(name: 'region', type: ColumnType.text),
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

  test('supportedLocales mirrors the built-in strings', () {
    expect(
      TesseraLocalizations.supportedLocales.map((l) => l.languageCode),
      TesseraStrings.supportedLanguages,
    );
    for (final locale in TesseraLocalizations.supportedLocales) {
      expect(TesseraLocalizations.delegate.isSupported(locale), isTrue);
    }
    expect(
      TesseraLocalizations.delegate.isSupported(const Locale('xx')),
      isFalse,
    );
  });

  testWidgets('of(context) falls back to English without a delegate', (
    tester,
  ) async {
    late TesseraStrings strings;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            strings = TesseraLocalizations.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(strings.languageCode, 'en');
  });

  testWidgets('the delegate resolves the app locale and ignores the country', (
    tester,
  ) async {
    late TesseraStrings strings;
    // A bare Localizations widget: MaterialApp would also need
    // flutter_localizations' delegates for a German Material locale.
    await tester.pumpWidget(
      Localizations(
        locale: const Locale('de', 'AT'),
        delegates: const [
          TesseraLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
          DefaultMaterialLocalizations.delegate,
        ],
        child: Builder(
          builder: (context) {
            strings = TesseraLocalizations.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(strings.languageCode, 'de');
    expect(
      TesseraLocalizations.delegate.isSupported(const Locale('pt', 'BR')),
      isTrue,
    );
    expect(
      TesseraLocalizations.delegate.isSupported(const Locale('xx')),
      isFalse,
    );
    expect(
      (await TesseraLocalizations.delegate.load(const Locale('zh', 'TW')))
          .languageCode,
      'zh',
    );
  });

  testWidgets('the scope overrides everything and the widgets use it', (
    tester,
  ) async {
    final controller = CubeController(
      Cube(
        facts: f,
        spec: CubeSpec(
          rows: CubeAxis.of([region]),
          columns: CubeAxis.of([month]),
          aggregates: [Aggregate.sum(total)],
        ),
      ),
    );
    await tester.pumpWidget(
      TesseraLocalizationsScope(
        strings: const TesseraStringsHu(),
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AxisEditor(controller: controller, side: AxisSide.rows),
                AxisEditor(controller: controller, side: AxisSide.columns),
                AggregateEditor(controller: controller),
                Expanded(
                  child: CubeView(
                    controller: controller,
                    aggregate: Aggregate.sum(total),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('Sorok'), findsOneWidget);
    expect(find.text('Oszlopok'), findsOneWidget);
    expect(find.text('Értékek'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'Revenue összege'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'Sold on hónap'), findsOneWidget);
    expect(find.text('január'), findsOneWidget); // column header for month 1
    expect(find.text('Összesen'), findsNWidgets(2));
    expect(find.text('Total'), findsNothing);
    // per-widget overrides still win
    await tester.pumpWidget(
      TesseraLocalizationsScope(
        strings: const TesseraStringsHu(),
        child: MaterialApp(
          home: Scaffold(
            body: CubeView(
              controller: controller,
              aggregate: Aggregate.sum(total),
              rowSummaryLabel: 'Mind',
            ),
          ),
        ),
      ),
    );
    expect(find.text('Mind'), findsOneWidget);
    expect(find.text('Összesen'), findsOneWidget);
  });

  testWidgets('the pickers are localized too', (tester) async {
    final controller = CubeController(
      Cube(
        facts: f,
        spec: CubeSpec(aggregates: [Aggregate.sum(total)]),
      ),
    );
    await tester.pumpWidget(
      TesseraLocalizationsScope(
        strings: const TesseraStringsDe(),
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AxisEditor(controller: controller, side: AxisSide.rows),
                AggregateEditor(controller: controller),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();
    expect(find.text('Dimension hinzufügen'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Sold on Monat'), findsOneWidget);
    await tester.tap(find.text('Cancel')); // Material's own localization (en)
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add).last);
    await tester.pumpAndSettle();
    expect(find.text('Aggregat hinzufügen'), findsOneWidget);
    expect(find.text('Summe'), findsOneWidget);
    expect(
      find.text('bereits verwendet'),
      findsOneWidget,
    ); // sum of Revenue is used
  });
}
