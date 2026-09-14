import '../cube/layout_aggregate.dart';
import '../facts/dimension.dart';
import 'tessera_strings.dart';

/// hu texts. Native review welcome.
final class TesseraStringsHu extends TesseraStrings {
  const TesseraStringsHu();

  @override
  String get languageCode => 'hu';

  @override
  String sumOf(String t) => '$t összege';

  @override
  String averageOf(String t) => '$t átlaga';

  @override
  String minimumOf(String t) => '$t minimuma';

  @override
  String maximumOf(String t) => '$t maximuma';

  @override
  String stdDevOf(String t) => '$t szórása';

  @override
  String stdDevPopulationOf(String t) => '$t sokasági szórása';

  @override
  String varianceOf(String t) => '$t varianciája';

  @override
  String variancePopulationOf(String t) => '$t sokasági varianciája';

  @override
  String countOf(String t) => '$t darabszáma';

  @override
  String distinctCountOf(String t) => '$t egyedi értékeinek száma';

  @override
  String get countLabel => 'darabszám';

  @override
  String percentOfTotal(String base, TotalOf of) => switch (of) {
    TotalOf.row => '$base a sor összegének %-ában',
    TotalOf.column => '$base az oszlop összegének %-ában',
    TotalOf.grand => '$base a végösszeg %-ában',
    TotalOf.parentRow => '$base a szülő sor %-ában',
    TotalOf.parentColumn => '$base a szülő oszlop %-ában',
  };

  @override
  String differenceFrom(String base, String item, {required bool percent}) =>
      percent
      ? '$base %-os eltérése ettől: $item'
      : '$base eltérése ettől: $item';

  @override
  String get previousItem => 'előző';

  @override
  String get nextItem => 'következő';

  @override
  String runningTotalOf(String base) => '$base göngyölítve';

  @override
  String rankOf(String base) => '$base rangsora';

  @override
  String get countOfFacts => 'Sorok száma';

  @override
  String get sum => 'Összeg';

  @override
  String get average => 'Átlag';

  @override
  String get minimum => 'Minimum';

  @override
  String get maximum => 'Maximum';

  @override
  String get standardDeviation => 'Szórás';

  @override
  String get populationStandardDeviation => 'Sokasági szórás';

  @override
  String get variance => 'Variancia';

  @override
  String get populationVariance => 'Sokasági variancia';

  @override
  String get countOfValues => 'Értékek száma';

  @override
  String get distinctCount => 'Egyedi értékek száma';

  @override
  String datePartName(DatePart part) => switch (part) {
    DatePart.year => 'év',
    DatePart.quarter => 'negyedév',
    DatePart.month => 'hónap',
    DatePart.week => 'hét',
    DatePart.day => 'nap',
    DatePart.weekday => 'hét napja',
    DatePart.hour => 'óra',
  };

  @override
  String datePartLabel(String column, DatePart part) {
    final p = datePartName(part);
    return '$column $p';
  }

  static const _months = [
    'január',
    'február',
    'március',
    'április',
    'május',
    'június',
    'július',
    'augusztus',
    'szeptember',
    'október',
    'november',
    'december',
  ];

  static const _weekdays = [
    'hétfő',
    'kedd',
    'szerda',
    'csütörtök',
    'péntek',
    'szombat',
    'vasárnap',
  ];

  @override
  String monthName(int month) => _months[month - 1];

  @override
  String weekdayName(int weekday) => _weekdays[weekday - 1];

  @override
  String quarter(int q) => '$q. n.év';

  @override
  String get decimalSeparator => ',';

  @override
  String get groupSeparator => '\u00A0';

  @override
  String get rows => 'Sorok';

  @override
  String get columns => 'Oszlopok';

  @override
  String get values => 'Értékek';

  @override
  String get emptyGroup => '(üres)';

  @override
  String get total => 'Összesen';

  @override
  String get dropDimensionsHere => 'Húzd ide a dimenziókat';

  @override
  String get addDimension => 'Dimenzió hozzáadása';

  @override
  String get addAggregate => 'Aggregátum hozzáadása';

  @override
  String get search => 'Keresés';

  @override
  String get alreadyInUse => 'már használatban';

  @override
  String get function => 'Függvény';

  @override
  String get expand => 'Kibontás';

  @override
  String get largeExpansionTitle => 'Nagy kibontás';

  @override
  String get sortAscending => 'Növekvő rendezés';

  @override
  String get sortDescending => 'Csökkenő rendezés';

  @override
  String get inheritSort => 'Sorrend a felső szint szerint';

  @override
  String get totalsAtEnd => 'Összesen a végén';

  @override
  String get totalsAtStart => 'Összesen az elején';

  @override
  String get totalsHidden => 'Összesen elrejtése';

  @override
  String get subtotalsAbove => 'Részösszeg a csoport felett';

  @override
  String get subtotalsBelow => 'Részösszeg a csoport alatt';

  @override
  String get subtotalsLeft => 'Részösszeg a csoport bal oldalán';

  @override
  String get subtotalsRight => 'Részösszeg a csoport jobb oldalán';

  @override
  String get subtotalsHidden => 'Részösszegek elrejtése';

  @override
  String get expandAll => 'Összes kibontása';

  @override
  String get collapseAll => 'Összes összecsukása';

  @override
  String largeExpansion(String label, int added, {required bool isRow}) =>
      'A(z) „$label” kibontása $added ${isRow ? 'sort' : 'oszlopot'} ad hozzá. Folytatod?';
}
