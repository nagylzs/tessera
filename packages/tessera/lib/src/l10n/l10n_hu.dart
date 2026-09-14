import '../cube/layout_aggregate.dart';
import '../expr/expr_type.dart';
import '../expr/expression_error.dart';
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
  String get showValuesAs => 'Értékek megjelenítése';

  @override
  String valueDisplayName(ValueDisplay display) => switch (display) {
    ValueDisplay.plain => 'Egyszerű érték',
    ValueDisplay.percentOfRow => 'A sor összegének %-ában',
    ValueDisplay.percentOfColumn => 'Az oszlop összegének %-ában',
    ValueDisplay.percentOfGrand => 'A végösszeg %-ában',
    ValueDisplay.percentOfParentRow => 'A szülő sor %-ában',
    ValueDisplay.percentOfParentColumn => 'A szülő oszlop %-ában',
    ValueDisplay.differenceFromPreviousRow => 'Eltérés az előző sortól',
    ValueDisplay.differenceFromPreviousColumn => 'Eltérés az előző oszloptól',
    ValueDisplay.percentDifferenceFromPreviousRow =>
      '%-os eltérés az előző sortól',
    ValueDisplay.percentDifferenceFromPreviousColumn =>
      '%-os eltérés az előző oszloptól',
    ValueDisplay.runningTotalRows => 'Göngyölített összeg soronként',
    ValueDisplay.runningTotalColumns => 'Göngyölített összeg oszloponként',
    ValueDisplay.rankRows => 'Rangsor a sorok között',
    ValueDisplay.rankColumns => 'Rangsor az oszlopok között',
  };

  @override
  String get formula => 'Képlet';

  @override
  String get labelField => 'Felirat';

  @override
  String get countOfFacts => 'Rekordok száma';

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

  @override
  String get filter => 'Szűrő';

  @override
  String get noFilter => 'Nincs szűrő';

  @override
  String get addCondition => 'Feltétel hozzáadása';

  @override
  String get addGroup => 'Csoport hozzáadása';

  @override
  String get addExpression => 'Kifejezés hozzáadása';

  @override
  String get matchAll => 'Mindegyik teljesül';

  @override
  String get matchAny => 'Bármelyik teljesül';

  @override
  String get negate => 'Nem';

  @override
  String get opEquals => 'egyenlő';

  @override
  String get opNotEquals => 'nem egyenlő';

  @override
  String get opLess => 'kisebb, mint';

  @override
  String get opLessOrEqual => 'legfeljebb';

  @override
  String get opGreater => 'nagyobb, mint';

  @override
  String get opGreaterOrEqual => 'legalább';

  @override
  String get opBetween => 'között';

  @override
  String get opContains => 'tartalmazza';

  @override
  String get opStartsWith => 'ezzel kezdődik';

  @override
  String get opEndsWith => 'ezzel végződik';

  @override
  String get opIsEmpty => 'üres';

  @override
  String get opIsNotEmpty => 'nem üres';

  @override
  String get opIsOneOf => 'ezek egyike';

  @override
  String get opIsTrue => 'igaz';

  @override
  String get opIsFalse => 'hamis';

  @override
  String get customFilter => 'Egyedi szűrő';

  @override
  String get expression => 'Kifejezés';

  @override
  String get selectValues => 'Értékek kiválasztása…';

  @override
  String selectedCount(int count) => '$count kiválasztva';

  @override
  String get clear => 'Törlés';

  @override
  String get apply => 'Alkalmaz';

  @override
  String get column => 'Oszlop';

  @override
  String get value => 'Érték';

  @override
  String exprTypeName(ExprType type) => switch (type) {
    ExprType.number => 'szám',
    ExprType.text => 'szöveg',
    ExprType.boolean => 'logikai',
    ExprType.date => 'dátum',
  };

  @override
  String expressionErrorText(ExpressionErrorKind kind, List<String> a) =>
      switch (kind) {
        ExpressionErrorKind.unexpectedCharacter =>
          'váratlan karakter: „${a[0]}”',
        ExpressionErrorKind.unterminatedText => 'lezáratlan szöveg',
        ExpressionErrorKind.unterminatedName => 'hiányzó „]” az oszlopnév után',
        ExpressionErrorKind.unterminatedDate => 'hiányzó „#” a dátum után',
        ExpressionErrorKind.invalidNumber => 'érvénytelen szám: „${a[0]}”',
        ExpressionErrorKind.invalidDate => 'érvénytelen dátum: „${a[0]}”',
        ExpressionErrorKind.unexpectedToken => 'váratlan „${a[0]}”',
        ExpressionErrorKind.unexpectedEnd => 'a kifejezés váratlanul véget ér',
        ExpressionErrorKind.unknownColumn => 'ismeretlen oszlop: „${a[0]}”',
        ExpressionErrorKind.unknownFunction => 'ismeretlen függvény: „${a[0]}”',
        ExpressionErrorKind.argumentCount =>
          'a(z) ${a[0]} ${a[1]} paramétert vár, ${a[2]} érkezett',
        ExpressionErrorKind.argumentType =>
          'a(z) ${a[0]} ${a[1]}. paramétere ${a[2]} kell legyen, nem ${a[3]}',
        ExpressionErrorKind.operandType =>
          'a(z) ${a[0]} operandusa ${a[1]} kell legyen, nem ${a[2]}',
        ExpressionErrorKind.incompatibleTypes =>
          'a(z) ${a[0]} nem alkalmazható erre: ${a[1]} és ${a[2]}',
        ExpressionErrorKind.unknownType => 'a típus nem állapítható meg',
        ExpressionErrorKind.notAllowedHere => '„${a[0]}” itt nem használható',
        ExpressionErrorKind.resultType =>
          'a kifejezésnek ${a[0]} típusúnak kell lennie, nem ${a[1]}',
      };
}
