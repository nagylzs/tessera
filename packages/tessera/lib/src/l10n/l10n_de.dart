import '../cube/layout_aggregate.dart';
import '../expr/expr_type.dart';
import '../expr/expression_error.dart';
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
  String stdDevOf(String t) => 'Standardabweichung von $t';

  @override
  String stdDevPopulationOf(String t) =>
      'Standardabweichung (Grundgesamtheit) von $t';

  @override
  String varianceOf(String t) => 'Varianz von $t';

  @override
  String variancePopulationOf(String t) => 'Varianz (Grundgesamtheit) von $t';

  @override
  String countOf(String t) => 'Anzahl von $t';

  @override
  String distinctCountOf(String t) => 'Anzahl verschiedener $t';

  @override
  String get countLabel => 'Anzahl';

  @override
  String percentOfTotal(String base, TotalOf of) => switch (of) {
    TotalOf.row => '$base % der Zeilensumme',
    TotalOf.column => '$base % der Spaltensumme',
    TotalOf.grand => '$base % der Gesamtsumme',
    TotalOf.parentRow => '$base % der übergeordneten Zeile',
    TotalOf.parentColumn => '$base % der übergeordneten Spalte',
  };

  @override
  String differenceFrom(String base, String item, {required bool percent}) =>
      percent ? '$base % Differenz von $item' : '$base Differenz von $item';

  @override
  String get previousItem => 'vorherige';

  @override
  String get nextItem => 'nächste';

  @override
  String runningTotalOf(String base) => '$base kumuliert';

  @override
  String rankOf(String base) => '$base Rang';

  @override
  String get showValuesAs => 'Werte anzeigen als';

  @override
  String valueDisplayName(ValueDisplay display) => switch (display) {
    ValueDisplay.plain => 'Einfacher Wert',
    ValueDisplay.percentOfRow => '% der Zeilensumme',
    ValueDisplay.percentOfColumn => '% der Spaltensumme',
    ValueDisplay.percentOfGrand => '% der Gesamtsumme',
    ValueDisplay.percentOfParentRow => '% der übergeordneten Zeile',
    ValueDisplay.percentOfParentColumn => '% der übergeordneten Spalte',
    ValueDisplay.differenceFromPreviousRow => 'Differenz zur vorherigen Zeile',
    ValueDisplay.differenceFromPreviousColumn =>
      'Differenz zur vorherigen Spalte',
    ValueDisplay.percentDifferenceFromPreviousRow =>
      '% Differenz zur vorherigen Zeile',
    ValueDisplay.percentDifferenceFromPreviousColumn =>
      '% Differenz zur vorherigen Spalte',
    ValueDisplay.runningTotalRows => 'Kumuliert über Zeilen',
    ValueDisplay.runningTotalColumns => 'Kumuliert über Spalten',
    ValueDisplay.rankRows => 'Rang unter den Zeilen',
    ValueDisplay.rankColumns => 'Rang unter den Spalten',
  };

  @override
  String get formula => 'Formel';

  @override
  String get labelField => 'Beschriftung';

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
  String get standardDeviation => 'Standardabweichung';

  @override
  String get populationStandardDeviation =>
      'Standardabweichung (Grundgesamtheit)';

  @override
  String get variance => 'Varianz';

  @override
  String get populationVariance => 'Varianz (Grundgesamtheit)';

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

  @override
  String get filter => 'Filter';

  @override
  String get noFilter => 'Kein Filter';

  @override
  String get addCondition => 'Bedingung hinzufügen';

  @override
  String get addGroup => 'Gruppe hinzufügen';

  @override
  String get addExpression => 'Ausdruck hinzufügen';

  @override
  String get matchAll => 'Alle Bedingungen';

  @override
  String get matchAny => 'Eine der Bedingungen';

  @override
  String get negate => 'Nicht';

  @override
  String get opEquals => 'ist gleich';

  @override
  String get opNotEquals => 'ist ungleich';

  @override
  String get opLess => 'ist kleiner als';

  @override
  String get opLessOrEqual => 'ist höchstens';

  @override
  String get opGreater => 'ist größer als';

  @override
  String get opGreaterOrEqual => 'ist mindestens';

  @override
  String get opBetween => 'liegt zwischen';

  @override
  String get opContains => 'enthält';

  @override
  String get opStartsWith => 'beginnt mit';

  @override
  String get opEndsWith => 'endet mit';

  @override
  String get opIsEmpty => 'ist leer';

  @override
  String get opIsNotEmpty => 'ist nicht leer';

  @override
  String get opIsOneOf => 'ist eines von';

  @override
  String get opIsTrue => 'ist wahr';

  @override
  String get opIsFalse => 'ist falsch';

  @override
  String get customFilter => 'Benutzerdefinierter Filter';

  @override
  String get expression => 'Ausdruck';

  @override
  String get selectValues => 'Werte auswählen…';

  @override
  String selectedCount(int count) => '$count ausgewählt';

  @override
  String get clear => 'Löschen';

  @override
  String get apply => 'Anwenden';

  @override
  String get column => 'Spalte';

  @override
  String get value => 'Wert';

  @override
  String exprTypeName(ExprType type) => switch (type) {
    ExprType.number => 'Zahl',
    ExprType.text => 'Text',
    ExprType.boolean => 'Wahrheitswert',
    ExprType.date => 'Datum',
  };

  @override
  String expressionErrorText(
    ExpressionErrorKind kind,
    List<String> a,
  ) => switch (kind) {
    ExpressionErrorKind.unexpectedCharacter => 'unerwartetes Zeichen „${a[0]}“',
    ExpressionErrorKind.unterminatedText => 'Textliteral nicht abgeschlossen',
    ExpressionErrorKind.unterminatedName => '„]“ nach dem Spaltennamen fehlt',
    ExpressionErrorKind.unterminatedDate => '„#“ nach dem Datum fehlt',
    ExpressionErrorKind.invalidNumber => 'ungültige Zahl „${a[0]}“',
    ExpressionErrorKind.invalidDate => 'ungültiges Datum „${a[0]}“',
    ExpressionErrorKind.unexpectedToken => 'unerwartetes „${a[0]}“',
    ExpressionErrorKind.unexpectedEnd => 'unerwartetes Ende des Ausdrucks',
    ExpressionErrorKind.unknownColumn => 'unbekannte Spalte „${a[0]}“',
    ExpressionErrorKind.unknownFunction => 'unbekannte Funktion „${a[0]}“',
    ExpressionErrorKind.argumentCount =>
      '${a[0]} erwartet ${a[1]} Argument(e), ${a[2]} angegeben',
    ExpressionErrorKind.argumentType =>
      'Argument ${a[1]} von ${a[0]} muss ${a[2]} sein, nicht ${a[3]}',
    ExpressionErrorKind.operandType =>
      'Operand von ${a[0]} muss ${a[1]} sein, nicht ${a[2]}',
    ExpressionErrorKind.incompatibleTypes =>
      '${a[0]} ist auf ${a[1]} und ${a[2]} nicht anwendbar',
    ExpressionErrorKind.unknownType => 'der Typ kann nicht bestimmt werden',
    ExpressionErrorKind.notAllowedHere => '„${a[0]}“ ist hier nicht erlaubt',
    ExpressionErrorKind.resultType =>
      'der Ausdruck muss ${a[0]} sein, nicht ${a[1]}',
  };
}
