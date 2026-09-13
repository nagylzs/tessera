import '../facts/dimension.dart';
import 'tessera_strings.dart';

/// cs texts. Native review welcome.
final class TesseraStringsCs extends TesseraStrings {
  const TesseraStringsCs();

  @override
  String get languageCode => 'cs';

  @override
  String sumOf(String t) => 'součet: $t';

  @override
  String averageOf(String t) => 'průměr: $t';

  @override
  String minimumOf(String t) => 'minimum: $t';

  @override
  String maximumOf(String t) => 'maximum: $t';

  @override
  String countOf(String t) => 'počet: $t';

  @override
  String distinctCountOf(String t) => 'jedinečné hodnoty: $t';

  @override
  String get countLabel => 'počet';

  @override
  String get countOfFacts => 'Počet řádků';

  @override
  String get sum => 'Součet';

  @override
  String get average => 'Průměr';

  @override
  String get minimum => 'Minimum';

  @override
  String get maximum => 'Maximum';

  @override
  String get countOfValues => 'Počet hodnot';

  @override
  String get distinctCount => 'Počet jedinečných hodnot';

  @override
  String datePartName(DatePart part) => switch (part) {
    DatePart.year => 'rok',
    DatePart.quarter => 'čtvrtletí',
    DatePart.month => 'měsíc',
    DatePart.week => 'týden',
    DatePart.day => 'den',
    DatePart.weekday => 'den v týdnu',
    DatePart.hour => 'hodina',
  };

  @override
  String datePartLabel(String column, DatePart part) {
    final p = datePartName(part);
    return '$column ($p)';
  }

  static const _months = [
    'leden',
    'únor',
    'březen',
    'duben',
    'květen',
    'červen',
    'červenec',
    'srpen',
    'září',
    'říjen',
    'listopad',
    'prosinec',
  ];

  static const _weekdays = [
    'pondělí',
    'úterý',
    'středa',
    'čtvrtek',
    'pátek',
    'sobota',
    'neděle',
  ];

  @override
  String monthName(int month) => _months[month - 1];

  @override
  String weekdayName(int weekday) => _weekdays[weekday - 1];

  @override
  String quarter(int q) => 'Q$q';

  @override
  String get decimalSeparator => ',';

  @override
  String get groupSeparator => '\u00A0';

  @override
  String get rows => 'Řádky';

  @override
  String get columns => 'Sloupce';

  @override
  String get values => 'Hodnoty';

  @override
  String get emptyGroup => '(prázdné)';

  @override
  String get total => 'Celkem';

  @override
  String get dropDimensionsHere => 'Přetáhněte dimenze sem';

  @override
  String get addDimension => 'Přidat dimenzi';

  @override
  String get addAggregate => 'Přidat agregát';

  @override
  String get search => 'Hledat';

  @override
  String get alreadyInUse => 'již použito';

  @override
  String get function => 'Funkce';

  @override
  String get expand => 'Rozbalit';

  @override
  String get largeExpansionTitle => 'Velké rozbalení';

  @override
  String get sortAscending => 'Seřadit vzestupně';

  @override
  String get sortDescending => 'Seřadit sestupně';

  @override
  String get inheritSort => 'Stejné pořadí jako úroveň výše';

  @override
  String get totalsAtEnd => 'Součty na konci';

  @override
  String get totalsAtStart => 'Součty na začátku';

  @override
  String get totalsHidden => 'Skrýt součty';

  @override
  String get expandAll => 'Rozbalit vše';

  @override
  String get collapseAll => 'Sbalit vše';

  @override
  String largeExpansion(String label, int added, {required bool isRow}) =>
      'Rozbalení „$label“ přidá $added ${isRow ? 'řádků' : 'sloupců'}. Pokračovat?';
}
