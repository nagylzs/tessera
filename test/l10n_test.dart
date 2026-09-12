import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tessera/tessera.dart';

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

  test('every supported locale has a built-in class', () {
    for (final locale in TesseraLocalizations.supportedLocales) {
      final l = TesseraLocalizations.forLanguage(locale.languageCode);
      expect(l, isNotNull, reason: locale.toString());
      expect(l!.languageCode, locale.languageCode);
    }
    expect(
      builtInLocalizations.length,
      TesseraLocalizations.supportedLocales.length,
    );
    expect(TesseraLocalizations.forLanguage('xx'), isNull);
  });

  test('every built-in locale is sane', () {
    for (final l in builtInLocalizations.values) {
      final tag = l.languageCode;
      final months = [for (var m = 1; m <= 12; m++) l.monthName(m)];
      final days = [for (var d = 1; d <= 7; d++) l.weekdayName(d)];
      expect(months.toSet().length, 12, reason: tag);
      expect(days.toSet().length, 7, reason: tag);
      expect(months.every((s) => s.isNotEmpty), isTrue, reason: tag);
      expect(days.every((s) => s.isNotEmpty), isTrue, reason: tag);
      expect(() => l.monthName(13), throwsRangeError, reason: tag);
      final kinds = AggregateKind.values.map(l.aggregateKindLabel).toList();
      expect(kinds.toSet().length, kinds.length, reason: '$tag kind labels');
      for (final part in DatePart.values) {
        expect(l.datePartName(part).isNotEmpty, isTrue, reason: '$tag $part');
        expect(l.datePartLabel('X', part), contains('X'), reason: '$tag $part');
      }
      for (final compose in [
        l.sumOf,
        l.averageOf,
        l.minimumOf,
        l.maximumOf,
        l.countOf,
        l.distinctCountOf,
      ]) {
        expect(compose('XYZ'), contains('XYZ'), reason: tag);
      }
      expect(l.quarter(3), contains('3'), reason: tag);
      final chrome = [
        l.rows,
        l.columns,
        l.values,
        l.emptyGroup,
        l.total,
        l.dropDimensionsHere,
        l.addDimension,
        l.addAggregate,
        l.search,
        l.alreadyInUse,
        l.function,
        l.expand,
        l.largeExpansionTitle,
        l.countLabel,
        l.countOfFacts,
        l.sum,
        l.average,
        l.minimum,
        l.maximum,
        l.countOfValues,
        l.distinctCount,
      ];
      expect(chrome.every((s) => s.trim().isNotEmpty), isTrue, reason: tag);
      final big = l.largeExpansion('G', 42, isRow: true);
      expect(big, contains('G'), reason: tag);
      expect(big, contains('42'), reason: tag);
      expect(
        big,
        isNot(equals(l.largeExpansion('G', 42, isRow: false))),
        reason: tag,
      );
      expect(l.decimalSeparator.length, 1, reason: tag);
      expect(l.groupSeparator.length, 1, reason: tag);
      expect(l.decimalSeparator, isNot(equals(l.groupSeparator)), reason: tag);
    }
  });

  test('label composition follows the locale', () {
    final en = TesseraLocalizations.forLanguage('en')!;
    final hu = TesseraLocalizations.forLanguage('hu')!;
    final pl = TesseraLocalizations.forLanguage('pl')!;
    final sumTotal = Aggregate.sum(total);
    expect(en.aggregateLabel(sumTotal, f), 'sum of Revenue');
    expect(hu.aggregateLabel(sumTotal, f), 'Revenue összege');
    expect(pl.aggregateLabel(sumTotal, f), 'suma: Revenue');
    expect(en.aggregateLabel(Aggregate.count, f), 'count');
    expect(
      hu.aggregateLabel(Aggregate.distinctCount(region), f),
      'region egyedi értékeinek száma',
    );
    // explicit labels are kept verbatim
    expect(
      hu.aggregateLabel(
        Aggregate.average(const Measure('total', label: 'Bevétel')),
        f,
      ),
      'Bevétel átlaga',
    );
    expect(hu.dimensionLabel(month, f), 'Sold on hónap');
    expect(en.dimensionLabel(month, f), 'Sold on month');
    expect(
      hu.dimensionLabel(
        const DatePartDimension('date', DatePart.month, label: 'Hó'),
        f,
      ),
      'Hó',
    );
    expect(hu.dimensionLabel(region, f), 'region');
    // custom aggregates fall back to their own label
    expect(hu.aggregateLabel(_Custom(), f), 'custom!');
  });

  test('values and numbers follow the locale', () {
    final en = TesseraLocalizations.forLanguage('en')!;
    final hu = TesseraLocalizations.forLanguage('hu')!;
    final de = TesseraLocalizations.forLanguage('de')!;
    expect(en.formatValue(month, 3), 'March');
    expect(hu.formatValue(month, 3), 'március');
    expect(
      hu.formatValue(const DatePartDimension('date', DatePart.weekday), 7),
      'vasárnap',
    );
    expect(
      hu.formatValue(const DatePartDimension('date', DatePart.quarter), 2),
      '2. n.év',
    );
    expect(
      en.formatValue(const DatePartDimension('date', DatePart.year), 2025),
      '2025',
    );
    expect(en.formatValue(region, 'Europe'), 'Europe');
    expect(en.formatValue(region, null), '');
    expect(en.formatValue(null, 5), '');
    expect(en.formatNumber(1234567.891), '1,234,567.89');
    expect(en.formatNumber(42), '42');
    expect(en.formatNumber(42.0), '42');
    expect(en.formatNumber(-1234.5), '-1,234.50');
    expect(en.formatNumber(999), '999');
    expect(hu.formatNumber(1234.5), '1 234,50');
    expect(de.formatNumber(1234567), '1.234.567');
  });

  testWidgets('of(context) falls back to English without a delegate', (
    tester,
  ) async {
    late TesseraLocalizations strings;
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
    late TesseraLocalizations strings;
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
        strings: const TesseraLocalizationsHu(),
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
        strings: const TesseraLocalizationsHu(),
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
        strings: const TesseraLocalizationsDe(),
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

final class _Custom extends Aggregate<int> {
  @override
  String get id => 'custom';
  @override
  String get label => 'custom!';
  @override
  AggregateAccumulator<int> createAccumulator() => throw UnimplementedError();
}
