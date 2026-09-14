import '../cube/layout_aggregate.dart';
import '../expr/expr_type.dart';
import '../expr/expression_error.dart';
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
  String stdDevOf(String t) => 'směrodatná odchylka: $t';

  @override
  String stdDevPopulationOf(String t) => 'směrodatná odchylka (populace): $t';

  @override
  String varianceOf(String t) => 'rozptyl: $t';

  @override
  String variancePopulationOf(String t) => 'rozptyl (populace): $t';

  @override
  String countOf(String t) => 'počet: $t';

  @override
  String distinctCountOf(String t) => 'jedinečné hodnoty: $t';

  @override
  String get countLabel => 'počet';

  @override
  String percentOfTotal(String base, TotalOf of) => switch (of) {
    TotalOf.row => '$base % ze součtu řádku',
    TotalOf.column => '$base % ze součtu sloupce',
    TotalOf.grand => '$base % z celkového součtu',
    TotalOf.parentRow => '$base % z nadřazeného řádku',
    TotalOf.parentColumn => '$base % z nadřazeného sloupce',
  };

  @override
  String differenceFrom(String base, String item, {required bool percent}) =>
      percent ? '$base % rozdíl od $item' : '$base rozdíl od $item';

  @override
  String get previousItem => 'předchozí';

  @override
  String get nextItem => 'následující';

  @override
  String runningTotalOf(String base) => '$base průběžný součet';

  @override
  String rankOf(String base) => '$base pořadí';

  @override
  String get showValuesAs => 'Zobrazit hodnoty jako';

  @override
  String valueDisplayName(ValueDisplay display) => switch (display) {
    ValueDisplay.plain => 'Prostá hodnota',
    ValueDisplay.percentOfRow => '% ze součtu řádku',
    ValueDisplay.percentOfColumn => '% ze součtu sloupce',
    ValueDisplay.percentOfGrand => '% z celkového součtu',
    ValueDisplay.percentOfParentRow => '% z nadřazeného řádku',
    ValueDisplay.percentOfParentColumn => '% z nadřazeného sloupce',
    ValueDisplay.differenceFromPreviousRow => 'Rozdíl od předchozího řádku',
    ValueDisplay.differenceFromPreviousColumn =>
      'Rozdíl od předchozího sloupce',
    ValueDisplay.percentDifferenceFromPreviousRow =>
      '% rozdíl od předchozího řádku',
    ValueDisplay.percentDifferenceFromPreviousColumn =>
      '% rozdíl od předchozího sloupce',
    ValueDisplay.runningTotalRows => 'Průběžný součet po řádcích',
    ValueDisplay.runningTotalColumns => 'Průběžný součet po sloupcích',
    ValueDisplay.rankRows => 'Pořadí mezi řádky',
    ValueDisplay.rankColumns => 'Pořadí mezi sloupci',
  };

  @override
  String get formula => 'Vzorec';

  @override
  String get labelField => 'Popisek';

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
  String get standardDeviation => 'Směrodatná odchylka';

  @override
  String get populationStandardDeviation => 'Směrodatná odchylka (populace)';

  @override
  String get variance => 'Rozptyl';

  @override
  String get populationVariance => 'Rozptyl (populace)';

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
  String get subtotalsAbove => 'Mezisoučty nad skupinou';

  @override
  String get subtotalsBelow => 'Mezisoučty pod skupinou';

  @override
  String get subtotalsLeft => 'Mezisoučty vlevo od skupiny';

  @override
  String get subtotalsRight => 'Mezisoučty vpravo od skupiny';

  @override
  String get subtotalsHidden => 'Skrýt mezisoučty';

  @override
  String get expandAll => 'Rozbalit vše';

  @override
  String get collapseAll => 'Sbalit vše';

  @override
  String largeExpansion(String label, int added, {required bool isRow}) =>
      'Rozbalení „$label“ přidá $added ${isRow ? 'řádků' : 'sloupců'}. Pokračovat?';

  @override
  String get filter => 'Filtr';

  @override
  String get noFilter => 'Bez filtru';

  @override
  String get addCondition => 'Přidat podmínku';

  @override
  String get addGroup => 'Přidat skupinu';

  @override
  String get addExpression => 'Přidat výraz';

  @override
  String get matchAll => 'Všechny podmínky';

  @override
  String get matchAny => 'Některá z podmínek';

  @override
  String get negate => 'Ne';

  @override
  String get opEquals => 'se rovná';

  @override
  String get opNotEquals => 'se nerovná';

  @override
  String get opLess => 'je menší než';

  @override
  String get opLessOrEqual => 'je nejvýše';

  @override
  String get opGreater => 'je větší než';

  @override
  String get opGreaterOrEqual => 'je nejméně';

  @override
  String get opBetween => 'je mezi';

  @override
  String get opContains => 'obsahuje';

  @override
  String get opStartsWith => 'začíná na';

  @override
  String get opEndsWith => 'končí na';

  @override
  String get opIsEmpty => 'je prázdné';

  @override
  String get opIsNotEmpty => 'není prázdné';

  @override
  String get opIsOneOf => 'je jedno z';

  @override
  String get opIsTrue => 'je pravda';

  @override
  String get opIsFalse => 'je nepravda';

  @override
  String get customFilter => 'Vlastní filtr';

  @override
  String get expression => 'Výraz';

  @override
  String get selectValues => 'Vybrat hodnoty…';

  @override
  String selectedCount(int count) => 'vybráno: $count';

  @override
  String get clear => 'Vymazat';

  @override
  String get apply => 'Použít';

  @override
  String get column => 'Sloupec';

  @override
  String get value => 'Hodnota';

  @override
  String exprTypeName(ExprType type) => switch (type) {
    ExprType.number => 'číslo',
    ExprType.text => 'text',
    ExprType.boolean => 'logická hodnota',
    ExprType.date => 'datum',
  };

  @override
  String expressionErrorText(ExpressionErrorKind kind, List<String> a) =>
      switch (kind) {
        ExpressionErrorKind.unexpectedCharacter => 'neočekávaný znak „${a[0]}“',
        ExpressionErrorKind.unterminatedText => 'neukončený textový literál',
        ExpressionErrorKind.unterminatedName => 'za názvem sloupce chybí „]“',
        ExpressionErrorKind.unterminatedDate => 'za datem chybí „#“',
        ExpressionErrorKind.invalidNumber => 'neplatné číslo „${a[0]}“',
        ExpressionErrorKind.invalidDate => 'neplatné datum „${a[0]}“',
        ExpressionErrorKind.unexpectedToken => 'neočekávané „${a[0]}“',
        ExpressionErrorKind.unexpectedEnd => 'neočekávaný konec výrazu',
        ExpressionErrorKind.unknownColumn => 'neznámý sloupec „${a[0]}“',
        ExpressionErrorKind.unknownFunction => 'neznámá funkce „${a[0]}“',
        ExpressionErrorKind.argumentCount =>
          '${a[0]} očekává ${a[1]} argument(y), zadáno ${a[2]}',
        ExpressionErrorKind.argumentType =>
          'argument ${a[1]} funkce ${a[0]} musí být ${a[2]}, ne ${a[3]}',
        ExpressionErrorKind.operandType =>
          'operand ${a[0]} musí být ${a[1]}, ne ${a[2]}',
        ExpressionErrorKind.incompatibleTypes =>
          '${a[0]} nelze použít na ${a[1]} a ${a[2]}',
        ExpressionErrorKind.unknownType => 'typ nelze určit',
        ExpressionErrorKind.notAllowedHere => '„${a[0]}“ zde není povoleno',
        ExpressionErrorKind.resultType => 'výraz musí být ${a[0]}, ne ${a[1]}',
      };
}
