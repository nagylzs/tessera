import 'expression_help.dart';

/// de texts of the expression help. Native review welcome.
final class ExpressionHelpStringsDe extends ExpressionHelpStrings {
  const ExpressionHelpStringsDe();

  @override
  String get languageCode => 'de';

  @override
  String get title => 'Hilfe zu Ausdrücken';

  @override
  String get tapToInsert =>
      'Zum Einfügen ein Beispiel, eine Spalte oder eine Funktion antippen.';

  @override
  String intro(ExpressionHelpUse use) => switch (use) {
    ExpressionHelpUse.filter =>
      'Ein Filter behält die Zeilen, für die der Ausdruck wahr ist. '
          'Bedingungen werden mit and, or und not verknüpft.',
    ExpressionHelpUse.measure =>
      'Eine berechnete Kennzahl wird für jede Zeile aus deren Spalten '
          'ermittelt und dann wie eine Spalte summiert oder gemittelt.',
    ExpressionHelpUse.dimension =>
      'Eine berechnete Dimension gruppiert die Zeilen wie eine Spalte nach '
          'dem Wert des Ausdrucks: Zahl, Text, Datum oder Wahrheitswert.',
    ExpressionHelpUse.formula =>
      'Eine Zellformel wird in jeder Zelle der Pivot-Tabelle aus den '
          'Aggregaten der Zelle berechnet, etwa sum(x) oder count.',
  };

  @override
  String get examples => 'Beispiele';

  @override
  String get columns => 'Spalten';

  @override
  String get aggregates => 'Aggregate';

  @override
  String get operators => 'Operatoren';

  @override
  String get values => 'Werte';

  @override
  String get rules => 'Regeln';

  @override
  String get functions => 'Funktionen';

  @override
  String get aggregateArgument =>
      'x ist eine Spalte oder eine Berechnung über die Spalten einer Zeile: '
      'sum(quantity * price). count allein zählt die Zeilen.';

  @override
  String groupName(ExpressionHelpGroup group) => switch (group) {
    ExpressionHelpGroup.conditional => 'Bedingungen',
    ExpressionHelpGroup.numbers => 'Zahlen',
    ExpressionHelpGroup.text => 'Text',
    ExpressionHelpGroup.dates => 'Datum und Uhrzeit',
    ExpressionHelpGroup.other => 'Weitere Funktionen',
  };

  @override
  String operatorText(ExpressionHelpOperator operator) => switch (operator) {
    ExpressionHelpOperator.arithmetic =>
      'Addieren, subtrahieren, multiplizieren, dividieren. Division durch '
          'null ergibt einen leeren Wert.',
    ExpressionHelpOperator.remainder => 'Der Rest einer Division: 7 % 3 ist 1.',
    ExpressionHelpOperator.comparison =>
      'Gleich, ungleich, kleiner, kleiner oder gleich, größer, größer oder '
          'gleich. == und != funktionieren auch.',
    ExpressionHelpOperator.logic =>
      'Beide Bedingungen, mindestens eine davon, das Gegenteil.',
    ExpressionHelpOperator.inList =>
      'x ist einer der aufgeführten Werte oder keiner davon.',
    ExpressionHelpOperator.between =>
      'a ≤ x ≤ b, beide Grenzen eingeschlossen.',
    ExpressionHelpOperator.emptyTest => 'x hat keinen Wert oder hat einen.',
    ExpressionHelpOperator.dates =>
      'n Tage nach oder vor einem Datum; die Tage zwischen zwei Datumswerten.',
  };

  @override
  String literalText(ExpressionHelpLiteral literal) => switch (literal) {
    ExpressionHelpLiteral.number =>
      'Zahlen, immer mit Dezimalpunkt: 12.5, nicht 12,5.',
    ExpressionHelpLiteral.text =>
      'Text in doppelten oder einfachen Anführungszeichen. Ein '
          'Anführungszeichen im Text wird verdoppelt: "say ""hi""".',
    ExpressionHelpLiteral.date =>
      'Datumswerte, bei Bedarf mit Uhrzeit, zwischen #-Zeichen, das Jahr '
          'zuerst.',
    ExpressionHelpLiteral.boolean => 'Wahrheitswerte.',
    ExpressionHelpLiteral.empty => 'Der leere Wert.',
    ExpressionHelpLiteral.name =>
      'Ein Spaltenname mit Leerzeichen oder Satzzeichen oder einer, der wie '
          'ein Schlüsselwort geschrieben wird, steht in eckigen Klammern.',
  };

  @override
  String ruleText(ExpressionHelpRule rule) => switch (rule) {
    ExpressionHelpRule.emptyValues =>
      'Eine Berechnung oder ein Vergleich mit einem leeren Wert ist leer: '
          'price * 2 und price > 0 sind leer, wo der Preis leer ist. '
          'coalesce(price, 0) verwendet stattdessen 0; price is empty findet '
          'die Zeilen ohne Preis.',
    ExpressionHelpRule.filters =>
      'Ein Filter behält eine Zeile nur, wenn sein Ausdruck für sie wahr '
          'ist: discount > 0 verwirft die Zeilen ohne Rabatt, '
          'discount > 0 or discount is empty behält sie.',
    ExpressionHelpRule.letterCase =>
      'Bei Funktionsnamen und Schlüsselwörtern ist die Groß- und '
          'Kleinschreibung beliebig (YEAR, Year); Spaltennamen müssen genau '
          'übereinstimmen. Textvergleiche unterscheiden Groß- und '
          'Kleinschreibung: lower(x) vergleichen, um sie zu ignorieren.',
  };

  @override
  ({String signature, String description}) function(
    ExpressionHelpFunction function,
  ) => switch (function) {
    ExpressionHelpFunction.ifElse => (
      signature: 'if(bedingung, a, b)',
      description:
          'a, wenn die Bedingung wahr ist, sonst b (auch wenn die Bedingung '
          'leer ist). a und b haben denselben Typ.',
    ),
    ExpressionHelpFunction.coalesce => (
      signature: 'coalesce(a, b, …)',
      description: 'Das erste seiner Argumente, das nicht leer ist.',
    ),
    ExpressionHelpFunction.isempty => (
      signature: 'isempty(x)',
      description: 'Wahr, wenn x leer ist; dasselbe wie x is empty.',
    ),
    ExpressionHelpFunction.abs => (
      signature: 'abs(x)',
      description: 'x ohne Vorzeichen.',
    ),
    ExpressionHelpFunction.round => (
      signature: 'round(x, stellen)',
      description:
          'x, gerundet auf stellen Nachkommastellen, ohne stellen auf eine '
          'ganze Zahl. Bei negativem stellen wird auf Zehner, Hunderter… '
          'gerundet: round(1234.5, -2) ist 1200.',
    ),
    ExpressionHelpFunction.floor => (
      signature: 'floor(x)',
      description:
          'x, abgerundet auf eine ganze Zahl: floor(2.7) ist 2, '
          'floor(-2.5) ist -3.',
    ),
    ExpressionHelpFunction.ceil => (
      signature: 'ceil(x)',
      description: 'x, aufgerundet auf eine ganze Zahl: ceil(2.1) ist 3.',
    ),
    ExpressionHelpFunction.sqrt => (
      signature: 'sqrt(x)',
      description: 'Die Quadratwurzel von x; leer bei negativem x.',
    ),
    ExpressionHelpFunction.min => (
      signature: 'min(x, y, …)',
      description: 'Die kleinste der Zahlen; leere werden übergangen.',
    ),
    ExpressionHelpFunction.max => (
      signature: 'max(x, y, …)',
      description: 'Die größte der Zahlen; leere werden übergangen.',
    ),
    ExpressionHelpFunction.number => (
      signature: 'number(text)',
      description:
          'Die in einem Text geschriebene Zahl, mit Dezimalpunkt; leer, wenn '
          'der Text keine Zahl ist.',
    ),
    ExpressionHelpFunction.len => (
      signature: 'len(text)',
      description: 'Die Anzahl der Zeichen im Text.',
    ),
    ExpressionHelpFunction.lower => (
      signature: 'lower(text)',
      description: 'Der Text in Kleinbuchstaben.',
    ),
    ExpressionHelpFunction.upper => (
      signature: 'upper(text)',
      description: 'Der Text in Großbuchstaben.',
    ),
    ExpressionHelpFunction.trim => (
      signature: 'trim(text)',
      description: 'Der Text ohne Leerzeichen am Anfang und am Ende.',
    ),
    ExpressionHelpFunction.left => (
      signature: 'left(text, n)',
      description: 'Die ersten n Zeichen des Textes.',
    ),
    ExpressionHelpFunction.right => (
      signature: 'right(text, n)',
      description: 'Die letzten n Zeichen des Textes.',
    ),
    ExpressionHelpFunction.substring => (
      signature: 'substring(text, start, länge)',
      description:
          'länge Zeichen des Textes ab Position start, wobei das erste '
          'Zeichen 1 ist; ohne länge der Rest des Textes.',
    ),
    ExpressionHelpFunction.contains => (
      signature: 'contains(text, teil)',
      description: 'Wahr, wenn teil im Text vorkommt.',
    ),
    ExpressionHelpFunction.startswith => (
      signature: 'startswith(text, teil)',
      description: 'Wahr, wenn der Text mit teil beginnt.',
    ),
    ExpressionHelpFunction.endswith => (
      signature: 'endswith(text, teil)',
      description: 'Wahr, wenn der Text mit teil endet.',
    ),
    ExpressionHelpFunction.replace => (
      signature: 'replace(text, alt, neu)',
      description: 'Der Text, in dem jedes alt durch neu ersetzt ist.',
    ),
    ExpressionHelpFunction.concat => (
      signature: 'concat(a, b, …)',
      description:
          'Die Texte aneinandergehängt; leere werden übergangen. text(x) '
          'macht aus einer Zahl oder einem Datum einen Text.',
    ),
    ExpressionHelpFunction.text => (
      signature: 'text(x)',
      description:
          'Eine Zahl, ein Datum oder ein Wahrheitswert als Text: text(1.5) '
          'ist "1.5", text(#2024-01-31#) ist "2024-01-31".',
    ),
    ExpressionHelpFunction.year => (
      signature: 'year(datum)',
      description: 'Das Jahr des Datums.',
    ),
    ExpressionHelpFunction.quarter => (
      signature: 'quarter(datum)',
      description: 'Das Quartal des Jahres, 1 bis 4.',
    ),
    ExpressionHelpFunction.month => (
      signature: 'month(datum)',
      description: 'Der Monat, 1 bis 12.',
    ),
    ExpressionHelpFunction.week => (
      signature: 'week(datum)',
      description: 'Die ISO-Kalenderwoche, 1 bis 53.',
    ),
    ExpressionHelpFunction.day => (
      signature: 'day(datum)',
      description: 'Der Tag des Monats, 1 bis 31.',
    ),
    ExpressionHelpFunction.weekday => (
      signature: 'weekday(datum)',
      description: 'Der Wochentag, 1 (Montag) bis 7 (Sonntag).',
    ),
    ExpressionHelpFunction.hour => (
      signature: 'hour(datum)',
      description: 'Die Stunde der Uhrzeit, 0 bis 23.',
    ),
    ExpressionHelpFunction.dateOfText => (
      signature: 'date(text)',
      description:
          'Das in einem Text geschriebene Datum, das Jahr zuerst: '
          'date("2024-01-31"); leer, wenn der Text kein Datum ist.',
    ),
    ExpressionHelpFunction.dateOfParts => (
      signature: 'date(jahr, monat, tag)',
      description: 'Das Datum aus dem angegebenen Jahr, Monat und Tag.',
    ),
    ExpressionHelpFunction.today => (
      signature: 'today()',
      description: 'Das heutige Datum.',
    ),
  };
}
