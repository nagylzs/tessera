import '../cube/layout_aggregate.dart';
import '../facts/dimension.dart';
import 'tessera_strings.dart';

/// pl texts. Native review welcome.
final class TesseraStringsPl extends TesseraStrings {
  const TesseraStringsPl();

  @override
  String get languageCode => 'pl';

  @override
  String sumOf(String t) => 'suma: $t';

  @override
  String averageOf(String t) => 'średnia: $t';

  @override
  String minimumOf(String t) => 'minimum: $t';

  @override
  String maximumOf(String t) => 'maksimum: $t';

  @override
  String stdDevOf(String t) => 'odchylenie standardowe: $t';

  @override
  String stdDevPopulationOf(String t) =>
      'odchylenie standardowe (populacja): $t';

  @override
  String varianceOf(String t) => 'wariancja: $t';

  @override
  String variancePopulationOf(String t) => 'wariancja (populacja): $t';

  @override
  String countOf(String t) => 'liczba: $t';

  @override
  String distinctCountOf(String t) => 'wartości unikalne: $t';

  @override
  String get countLabel => 'liczba';

  @override
  String percentOfTotal(String base, TotalOf of) => switch (of) {
    TotalOf.row => '$base % sumy wiersza',
    TotalOf.column => '$base % sumy kolumny',
    TotalOf.grand => '$base % sumy końcowej',
    TotalOf.parentRow => '$base % wiersza nadrzędnego',
    TotalOf.parentColumn => '$base % kolumny nadrzędnej',
  };

  @override
  String differenceFrom(String base, String item, {required bool percent}) =>
      percent ? '$base % różnicy od $item' : '$base różnica od $item';

  @override
  String get previousItem => 'poprzedni';

  @override
  String get nextItem => 'następny';

  @override
  String runningTotalOf(String base) => '$base suma bieżąca';

  @override
  String rankOf(String base) => '$base ranga';

  @override
  String get countOfFacts => 'Liczba wierszy';

  @override
  String get sum => 'Suma';

  @override
  String get average => 'Średnia';

  @override
  String get minimum => 'Minimum';

  @override
  String get maximum => 'Maksimum';

  @override
  String get standardDeviation => 'Odchylenie standardowe';

  @override
  String get populationStandardDeviation =>
      'Odchylenie standardowe (populacja)';

  @override
  String get variance => 'Wariancja';

  @override
  String get populationVariance => 'Wariancja (populacja)';

  @override
  String get countOfValues => 'Liczba wartości';

  @override
  String get distinctCount => 'Liczba unikalnych wartości';

  @override
  String datePartName(DatePart part) => switch (part) {
    DatePart.year => 'rok',
    DatePart.quarter => 'kwartał',
    DatePart.month => 'miesiąc',
    DatePart.week => 'tydzień',
    DatePart.day => 'dzień',
    DatePart.weekday => 'dzień tygodnia',
    DatePart.hour => 'godzina',
  };

  @override
  String datePartLabel(String column, DatePart part) {
    final p = datePartName(part);
    return '$column ($p)';
  }

  static const _months = [
    'styczeń',
    'luty',
    'marzec',
    'kwiecień',
    'maj',
    'czerwiec',
    'lipiec',
    'sierpień',
    'wrzesień',
    'październik',
    'listopad',
    'grudzień',
  ];

  static const _weekdays = [
    'poniedziałek',
    'wtorek',
    'środa',
    'czwartek',
    'piątek',
    'sobota',
    'niedziela',
  ];

  @override
  String monthName(int month) => _months[month - 1];

  @override
  String weekdayName(int weekday) => _weekdays[weekday - 1];

  @override
  String quarter(int q) => '$q kw.';

  @override
  String get decimalSeparator => ',';

  @override
  String get groupSeparator => '\u00A0';

  @override
  String get rows => 'Wiersze';

  @override
  String get columns => 'Kolumny';

  @override
  String get values => 'Wartości';

  @override
  String get emptyGroup => '(puste)';

  @override
  String get total => 'Razem';

  @override
  String get dropDimensionsHere => 'Upuść wymiary tutaj';

  @override
  String get addDimension => 'Dodaj wymiar';

  @override
  String get addAggregate => 'Dodaj agregat';

  @override
  String get search => 'Szukaj';

  @override
  String get alreadyInUse => 'już w użyciu';

  @override
  String get function => 'Funkcja';

  @override
  String get expand => 'Rozwiń';

  @override
  String get largeExpansionTitle => 'Duże rozwinięcie';

  @override
  String get sortAscending => 'Sortuj rosnąco';

  @override
  String get sortDescending => 'Sortuj malejąco';

  @override
  String get inheritSort => 'Kolejność jak na poziomie wyżej';

  @override
  String get totalsAtEnd => 'Sumy na końcu';

  @override
  String get totalsAtStart => 'Sumy na początku';

  @override
  String get totalsHidden => 'Ukryj sumy';

  @override
  String get subtotalsAbove => 'Sumy częściowe nad grupą';

  @override
  String get subtotalsBelow => 'Sumy częściowe pod grupą';

  @override
  String get subtotalsLeft => 'Sumy częściowe na lewo od grupy';

  @override
  String get subtotalsRight => 'Sumy częściowe na prawo od grupy';

  @override
  String get subtotalsHidden => 'Ukryj sumy częściowe';

  @override
  String get expandAll => 'Rozwiń wszystko';

  @override
  String get collapseAll => 'Zwiń wszystko';

  @override
  String largeExpansion(String label, int added, {required bool isRow}) =>
      'Rozwinięcie „$label” doda $added ${isRow ? 'wierszy' : 'kolumn'}. Kontynuować?';
}
