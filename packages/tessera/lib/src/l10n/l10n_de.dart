import '../facts/dimension.dart';
import 'tessera_strings.dart';

/// de texts. Native review welcome.
final class TesseraStringsDe extends TesseraStrings {
  const TesseraStringsDe();

  @override
  String get languageCode => 'de';

  @override
  String sumOf(String t) => 'Summe von $t';

  @override
  String averageOf(String t) => 'Durchschnitt von $t';

  @override
  String minimumOf(String t) => 'Minimum von $t';

  @override
  String maximumOf(String t) => 'Maximum von $t';

  @override
  String countOf(String t) => 'Anzahl von $t';

  @override
  String distinctCountOf(String t) => 'Anzahl verschiedener $t';

  @override
  String get countLabel => 'Anzahl';

  @override
  String get countOfFacts => 'Anzahl der Datensätze';

  @override
  String get sum => 'Summe';

  @override
  String get average => 'Durchschnitt';

  @override
  String get minimum => 'Minimum';

  @override
  String get maximum => 'Maximum';

  @override
  String get countOfValues => 'Anzahl der Werte';

  @override
  String get distinctCount => 'Anzahl verschiedener Werte';

  @override
  String datePartName(DatePart part) => switch (part) {
    DatePart.year => 'Jahr',
    DatePart.quarter => 'Quartal',
    DatePart.month => 'Monat',
    DatePart.week => 'Woche',
    DatePart.day => 'Tag',
    DatePart.weekday => 'Wochentag',
    DatePart.hour => 'Stunde',
  };

  @override
  String datePartLabel(String column, DatePart part) {
    final p = datePartName(part);
    return '$column $p';
  }

  static const _months = [
    'Januar',
    'Februar',
    'März',
    'April',
    'Mai',
    'Juni',
    'Juli',
    'August',
    'September',
    'Oktober',
    'November',
    'Dezember',
  ];

  static const _weekdays = [
    'Montag',
    'Dienstag',
    'Mittwoch',
    'Donnerstag',
    'Freitag',
    'Samstag',
    'Sonntag',
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
  String get groupSeparator => '.';

  @override
  String get rows => 'Zeilen';

  @override
  String get columns => 'Spalten';

  @override
  String get values => 'Werte';

  @override
  String get emptyGroup => '(leer)';

  @override
  String get total => 'Gesamt';

  @override
  String get dropDimensionsHere => 'Dimensionen hierher ziehen';

  @override
  String get addDimension => 'Dimension hinzufügen';

  @override
  String get addAggregate => 'Aggregat hinzufügen';

  @override
  String get search => 'Suchen';

  @override
  String get alreadyInUse => 'bereits verwendet';

  @override
  String get function => 'Funktion';

  @override
  String get expand => 'Ausklappen';

  @override
  String get largeExpansionTitle => 'Große Erweiterung';

  @override
  String get sortAscending => 'Aufsteigend sortieren';

  @override
  String get sortDescending => 'Absteigend sortieren';

  @override
  String get inheritSort => 'Reihenfolge wie die Ebene darüber';

  @override
  String get totalsAtEnd => 'Summen am Ende';

  @override
  String get totalsAtStart => 'Summen am Anfang';

  @override
  String get totalsHidden => 'Summen ausblenden';

  @override
  String get subtotalsAbove => 'Zwischensummen über der Gruppe';

  @override
  String get subtotalsBelow => 'Zwischensummen unter der Gruppe';

  @override
  String get subtotalsLeft => 'Zwischensummen links der Gruppe';

  @override
  String get subtotalsRight => 'Zwischensummen rechts der Gruppe';

  @override
  String get subtotalsHidden => 'Zwischensummen ausblenden';

  @override
  String get expandAll => 'Alle ausklappen';

  @override
  String get collapseAll => 'Alle einklappen';

  @override
  String largeExpansion(String label, int added, {required bool isRow}) =>
      'Das Ausklappen von „$label“ fügt $added ${isRow ? 'Zeilen' : 'Spalten'} hinzu. Fortfahren?';
}
