import '../facts/dimension.dart';
import 'tessera_strings.dart';

/// nl texts. Native review welcome.
final class TesseraStringsNl extends TesseraStrings {
  const TesseraStringsNl();

  @override
  String get languageCode => 'nl';

  @override
  String sumOf(String t) => 'som van $t';

  @override
  String averageOf(String t) => 'gemiddelde van $t';

  @override
  String minimumOf(String t) => 'minimum van $t';

  @override
  String maximumOf(String t) => 'maximum van $t';

  @override
  String countOf(String t) => 'aantal van $t';

  @override
  String distinctCountOf(String t) => 'unieke waarden van $t';

  @override
  String get countLabel => 'aantal';

  @override
  String get countOfFacts => 'Aantal rijen';

  @override
  String get sum => 'Som';

  @override
  String get average => 'Gemiddelde';

  @override
  String get minimum => 'Minimum';

  @override
  String get maximum => 'Maximum';

  @override
  String get countOfValues => 'Aantal waarden';

  @override
  String get distinctCount => 'Aantal unieke waarden';

  @override
  String datePartName(DatePart part) => switch (part) {
    DatePart.year => 'jaar',
    DatePart.quarter => 'kwartaal',
    DatePart.month => 'maand',
    DatePart.week => 'week',
    DatePart.day => 'dag',
    DatePart.weekday => 'weekdag',
    DatePart.hour => 'uur',
  };

  @override
  String datePartLabel(String column, DatePart part) {
    final p = datePartName(part);
    return '$column $p';
  }

  static const _months = [
    'januari',
    'februari',
    'maart',
    'april',
    'mei',
    'juni',
    'juli',
    'augustus',
    'september',
    'oktober',
    'november',
    'december',
  ];

  static const _weekdays = [
    'maandag',
    'dinsdag',
    'woensdag',
    'donderdag',
    'vrijdag',
    'zaterdag',
    'zondag',
  ];

  @override
  String monthName(int month) => _months[month - 1];

  @override
  String weekdayName(int weekday) => _weekdays[weekday - 1];

  @override
  String quarter(int q) => 'K$q';

  @override
  String get decimalSeparator => ',';

  @override
  String get groupSeparator => '.';

  @override
  String get rows => 'Rijen';

  @override
  String get columns => 'Kolommen';

  @override
  String get values => 'Waarden';

  @override
  String get emptyGroup => '(leeg)';

  @override
  String get total => 'Totaal';

  @override
  String get dropDimensionsHere => 'Sleep dimensies hierheen';

  @override
  String get addDimension => 'Dimensie toevoegen';

  @override
  String get addAggregate => 'Aggregaat toevoegen';

  @override
  String get search => 'Zoeken';

  @override
  String get alreadyInUse => 'al in gebruik';

  @override
  String get function => 'Functie';

  @override
  String get expand => 'Uitklappen';

  @override
  String get largeExpansionTitle => 'Grote uitbreiding';

  @override
  String get sortAscending => 'Oplopend sorteren';

  @override
  String get sortDescending => 'Aflopend sorteren';

  @override
  String get expandAll => 'Alles uitklappen';

  @override
  String get collapseAll => 'Alles inklappen';

  @override
  String largeExpansion(String label, int added, {required bool isRow}) =>
      'Het uitklappen van "$label" voegt $added ${isRow ? 'rijen' : 'kolommen'} toe. Doorgaan?';
}
