import '../cube/layout_aggregate.dart';
import '../expr/expr_type.dart';
import '../expr/expression_error.dart';
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
  String stdDevOf(String t) => 'standaardafwijking van $t';

  @override
  String stdDevPopulationOf(String t) =>
      'standaardafwijking (populatie) van $t';

  @override
  String varianceOf(String t) => 'variantie van $t';

  @override
  String variancePopulationOf(String t) => 'variantie (populatie) van $t';

  @override
  String countOf(String t) => 'aantal van $t';

  @override
  String distinctCountOf(String t) => 'unieke waarden van $t';

  @override
  String get countLabel => 'aantal';

  @override
  String percentOfTotal(String base, TotalOf of) => switch (of) {
    TotalOf.row => '$base % van rijtotaal',
    TotalOf.column => '$base % van kolomtotaal',
    TotalOf.grand => '$base % van eindtotaal',
    TotalOf.parentRow => '$base % van bovenliggende rij',
    TotalOf.parentColumn => '$base % van bovenliggende kolom',
  };

  @override
  String differenceFrom(String base, String item, {required bool percent}) =>
      percent ? '$base % verschil met $item' : '$base verschil met $item';

  @override
  String get previousItem => 'vorige';

  @override
  String get nextItem => 'volgende';

  @override
  String runningTotalOf(String base) => '$base lopend totaal';

  @override
  String rankOf(String base) => '$base rang';

  @override
  String get showValuesAs => 'Waarden weergeven als';

  @override
  String valueDisplayName(ValueDisplay display) => switch (display) {
    ValueDisplay.plain => 'Gewone waarde',
    ValueDisplay.percentOfRow => '% van rijtotaal',
    ValueDisplay.percentOfColumn => '% van kolomtotaal',
    ValueDisplay.percentOfGrand => '% van eindtotaal',
    ValueDisplay.percentOfParentRow => '% van bovenliggende rij',
    ValueDisplay.percentOfParentColumn => '% van bovenliggende kolom',
    ValueDisplay.differenceFromPreviousRow => 'Verschil met vorige rij',
    ValueDisplay.differenceFromPreviousColumn => 'Verschil met vorige kolom',
    ValueDisplay.percentDifferenceFromPreviousRow =>
      '% verschil met vorige rij',
    ValueDisplay.percentDifferenceFromPreviousColumn =>
      '% verschil met vorige kolom',
    ValueDisplay.runningTotalRows => 'Lopend totaal over rijen',
    ValueDisplay.runningTotalColumns => 'Lopend totaal over kolommen',
    ValueDisplay.rankRows => 'Rang binnen rijen',
    ValueDisplay.rankColumns => 'Rang binnen kolommen',
  };

  @override
  String get formula => 'Formule';

  @override
  String get labelField => 'Label';

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
  String get standardDeviation => 'Standaardafwijking';

  @override
  String get populationStandardDeviation => 'Standaardafwijking (populatie)';

  @override
  String get variance => 'Variantie';

  @override
  String get populationVariance => 'Variantie (populatie)';

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
  String get inheritSort => 'Zelfde volgorde als het niveau erboven';

  @override
  String get totalsAtEnd => 'Totalen aan het einde';

  @override
  String get totalsAtStart => 'Totalen aan het begin';

  @override
  String get totalsHidden => 'Totalen verbergen';

  @override
  String get subtotalsAbove => 'Subtotalen boven de groep';

  @override
  String get subtotalsBelow => 'Subtotalen onder de groep';

  @override
  String get subtotalsLeft => 'Subtotalen links van de groep';

  @override
  String get subtotalsRight => 'Subtotalen rechts van de groep';

  @override
  String get subtotalsHidden => 'Subtotalen verbergen';

  @override
  String get expandAll => 'Alles uitklappen';

  @override
  String get collapseAll => 'Alles inklappen';

  @override
  String largeExpansion(String label, int added, {required bool isRow}) =>
      'Het uitklappen van "$label" voegt $added ${isRow ? 'rijen' : 'kolommen'} toe. Doorgaan?';

  @override
  String get filter => 'Filter';

  @override
  String get noFilter => 'Geen filter';

  @override
  String get addCondition => 'Voorwaarde toevoegen';

  @override
  String get addGroup => 'Groep toevoegen';

  @override
  String get addExpression => 'Expressie toevoegen';

  @override
  String get matchAll => 'Alle voorwaarden';

  @override
  String get matchAny => 'Een van de voorwaarden';

  @override
  String get negate => 'Niet';

  @override
  String get opEquals => 'is gelijk aan';

  @override
  String get opNotEquals => 'is ongelijk aan';

  @override
  String get opLess => 'is kleiner dan';

  @override
  String get opLessOrEqual => 'is hoogstens';

  @override
  String get opGreater => 'is groter dan';

  @override
  String get opGreaterOrEqual => 'is minstens';

  @override
  String get opBetween => 'ligt tussen';

  @override
  String get opContains => 'bevat';

  @override
  String get opStartsWith => 'begint met';

  @override
  String get opEndsWith => 'eindigt op';

  @override
  String get opIsEmpty => 'is leeg';

  @override
  String get opIsNotEmpty => 'is niet leeg';

  @override
  String get opIsOneOf => 'is een van';

  @override
  String get opIsTrue => 'is waar';

  @override
  String get opIsFalse => 'is onwaar';

  @override
  String get customFilter => 'Aangepast filter';

  @override
  String get expression => 'Expressie';

  @override
  String get selectValues => 'Waarden kiezen…';

  @override
  String selectedCount(int count) => '$count geselecteerd';

  @override
  String get clear => 'Wissen';

  @override
  String get apply => 'Toepassen';

  @override
  String get column => 'Kolom';

  @override
  String get value => 'Waarde';

  @override
  String exprTypeName(ExprType type) => switch (type) {
    ExprType.number => 'getal',
    ExprType.text => 'tekst',
    ExprType.boolean => 'booleaans',
    ExprType.date => 'datum',
  };

  @override
  String expressionErrorText(
    ExpressionErrorKind kind,
    List<String> a,
  ) => switch (kind) {
    ExpressionErrorKind.unexpectedCharacter => 'onverwacht teken "${a[0]}"',
    ExpressionErrorKind.unterminatedText => 'tekst niet afgesloten',
    ExpressionErrorKind.unterminatedName => '"]" ontbreekt na de kolomnaam',
    ExpressionErrorKind.unterminatedDate => '"#" ontbreekt na de datum',
    ExpressionErrorKind.invalidNumber => 'ongeldig getal "${a[0]}"',
    ExpressionErrorKind.invalidDate => 'ongeldige datum "${a[0]}"',
    ExpressionErrorKind.unexpectedToken => 'onverwacht "${a[0]}"',
    ExpressionErrorKind.unexpectedEnd => 'onverwacht einde van de expressie',
    ExpressionErrorKind.unknownColumn => 'onbekende kolom "${a[0]}"',
    ExpressionErrorKind.unknownFunction => 'onbekende functie "${a[0]}"',
    ExpressionErrorKind.argumentCount =>
      '${a[0]} verwacht ${a[1]} argument(en), ${a[2]} opgegeven',
    ExpressionErrorKind.argumentType =>
      'argument ${a[1]} van ${a[0]} moet ${a[2]} zijn, niet ${a[3]}',
    ExpressionErrorKind.operandType =>
      'operand van ${a[0]} moet ${a[1]} zijn, niet ${a[2]}',
    ExpressionErrorKind.incompatibleTypes =>
      '${a[0]} is niet toepasbaar op ${a[1]} en ${a[2]}',
    ExpressionErrorKind.unknownType => 'het type kan niet worden bepaald',
    ExpressionErrorKind.notAllowedHere => '"${a[0]}" is hier niet toegestaan',
    ExpressionErrorKind.resultType =>
      'de expressie moet ${a[0]} zijn, niet ${a[1]}',
  };
}
