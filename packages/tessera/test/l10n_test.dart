import 'package:test/test.dart';
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

  test('every supported language has a built-in class', () {
    for (final code in TesseraStrings.supportedLanguages) {
      final l = TesseraStrings.forLanguage(code);
      expect(l, isNotNull, reason: code);
      expect(l!.languageCode, code);
    }
    expect(builtInStrings.length, TesseraStrings.supportedLanguages.length);
    expect(TesseraStrings.forLanguage('xx'), isNull);
  });

  test('every built-in locale is sane', () {
    for (final l in builtInStrings.values) {
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
        l.sortAscending,
        l.sortDescending,
        l.inheritSort,
        l.totalsAtEnd,
        l.totalsAtStart,
        l.totalsHidden,
        l.subtotalsAbove,
        l.subtotalsBelow,
        l.subtotalsLeft,
        l.subtotalsRight,
        l.subtotalsHidden,
        l.expandAll,
        l.collapseAll,
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
    final en = TesseraStrings.forLanguage('en')!;
    final hu = TesseraStrings.forLanguage('hu')!;
    final pl = TesseraStrings.forLanguage('pl')!;
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
    final en = TesseraStrings.forLanguage('en')!;
    final hu = TesseraStrings.forLanguage('hu')!;
    final de = TesseraStrings.forLanguage('de')!;
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
}

final class _Custom extends Aggregate<int> {
  @override
  String get id => 'custom';
  @override
  String get label => 'custom!';
  @override
  AggregateAccumulator<int> createAccumulator() => throw UnimplementedError();
}
