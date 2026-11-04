import 'expression_help.dart';

/// pl texts of the expression help. Native review welcome.
final class ExpressionHelpStringsPl extends ExpressionHelpStrings {
  const ExpressionHelpStringsPl();

  @override
  String get languageCode => 'pl';

  @override
  String get title => 'Pomoc do wyrażeń';

  @override
  String get tapToInsert =>
      'Dotknięciem wstawisz przykład, kolumnę lub funkcję.';

  @override
  String intro(ExpressionHelpUse use) => switch (use) {
    ExpressionHelpUse.filter =>
      'Filtr zachowuje wiersze, dla których wyrażenie jest '
          'prawdziwe. Warunki łączy się operatorami and, or i not.',
    ExpressionHelpUse.measure =>
      'Miarę obliczaną wylicza się dla każdego wiersza z jego '
          'kolumn, a następnie sumuje lub uśrednia jak kolumnę.',
    ExpressionHelpUse.dimension =>
      'Wymiar obliczany grupuje wiersze według wartości wyrażenia, '
          'tak jak kolumna. Wartością może być liczba, tekst, data lub '
          'prawda/fałsz.',
    ExpressionHelpUse.formula =>
      'Formułę komórki oblicza się w każdej komórce tabeli '
          'przestawnej z agregatów tej komórki, takich jak sum(x) czy '
          'count.',
  };

  @override
  String get examples => 'Przykłady';

  @override
  String get columns => 'Kolumny';

  @override
  String get aggregates => 'Agregaty';

  @override
  String get operators => 'Operatory';

  @override
  String get values => 'Wartości';

  @override
  String get rules => 'Zasady';

  @override
  String get functions => 'Funkcje';

  @override
  String get aggregateArgument =>
      'x to kolumna lub obliczenie na kolumnach wiersza: '
      'sum(quantity * price). Samo count zlicza wiersze.';

  @override
  String groupName(ExpressionHelpGroup group) => switch (group) {
    ExpressionHelpGroup.conditional => 'Warunki',
    ExpressionHelpGroup.numbers => 'Liczby',
    ExpressionHelpGroup.text => 'Tekst',
    ExpressionHelpGroup.dates => 'Daty',
    ExpressionHelpGroup.other => 'Inne funkcje',
  };

  @override
  String operatorText(ExpressionHelpOperator operator) => switch (operator) {
    ExpressionHelpOperator.arithmetic =>
      'Dodawanie, odejmowanie, mnożenie, dzielenie. Dzielenie przez '
          'zero daje pustą wartość.',
    ExpressionHelpOperator.remainder => 'Reszta z dzielenia: 7 % 3 daje 1.',
    ExpressionHelpOperator.comparison =>
      'Równe, różne, mniejsze, mniejsze lub równe, większe, większe '
          'lub równe. Działają też == i !=.',
    ExpressionHelpOperator.logic =>
      'Oba warunki, którykolwiek z nich, zaprzeczenie.',
    ExpressionHelpOperator.inList =>
      'x jest jedną z wymienionych wartości albo żadną z nich.',
    ExpressionHelpOperator.between => 'a ≤ x ≤ b, oba końce włącznie.',
    ExpressionHelpOperator.emptyTest => 'x nie ma wartości albo ją ma.',
    ExpressionHelpOperator.dates =>
      'n dni po dacie lub przed nią; liczba dni między dwiema datami.',
  };

  @override
  String literalText(ExpressionHelpLiteral literal) => switch (literal) {
    ExpressionHelpLiteral.number =>
      'Liczby, zawsze z kropką dziesiętną: 12.5, nie 12,5.',
    ExpressionHelpLiteral.text =>
      'Tekst w cudzysłowie podwójnym lub pojedynczym. Cudzysłów '
          'wewnątrz tekstu się podwaja: "say ""hi""".',
    ExpressionHelpLiteral.date =>
      'Daty, w razie potrzeby z godziną, między znakami #, najpierw '
          'rok.',
    ExpressionHelpLiteral.boolean => 'Wartości logiczne.',
    ExpressionHelpLiteral.empty => 'Pusta wartość.',
    ExpressionHelpLiteral.name =>
      'Nazwę kolumny ze spacjami lub znakami interpunkcyjnymi albo '
          'pisaną jak słowo kluczowe ujmuje się w nawiasy kwadratowe.',
  };

  @override
  String ruleText(ExpressionHelpRule rule) => switch (rule) {
    ExpressionHelpRule.emptyValues =>
      'Obliczenie lub porównanie z pustą wartością jest puste: price '
          '* 2 i price > 0 są puste tam, gdzie kolumna price jest pusta. '
          'coalesce(price, 0) podstawia wtedy 0; price is empty znajduje '
          'wiersze bez ceny.',
    ExpressionHelpRule.filters =>
      'Filtr zachowuje wiersz tylko wtedy, gdy jego wyrażenie jest '
          'prawdziwe: discount > 0 odrzuca wiersze bez rabatu, a '
          'discount > 0 or discount is empty je zachowuje.',
    ExpressionHelpRule.letterCase =>
      'Nazwy funkcji i słowa kluczowe można pisać literami dowolnej '
          'wielkości (YEAR, Year); nazwy kolumn muszą się zgadzać '
          'dokładnie. Porównania tekstu uwzględniają wielkość liter: aby '
          'ją pominąć, porównuj lower(x).',
  };

  @override
  ({String signature, String description}) function(
    ExpressionHelpFunction function,
  ) => switch (function) {
    ExpressionHelpFunction.ifElse => (
      signature: 'if(warunek, a, b)',
      description:
          'Wartość a, gdy warunek jest prawdziwy, w przeciwnym razie b '
          '(także gdy warunek jest pusty). Argumenty a i b mają ten sam '
          'typ.',
    ),
    ExpressionHelpFunction.coalesce => (
      signature: 'coalesce(a, b, …)',
      description: 'Pierwszy z argumentów, który nie jest pusty.',
    ),
    ExpressionHelpFunction.isempty => (
      signature: 'isempty(x)',
      description: 'Prawda, gdy x jest puste; to samo co x is empty.',
    ),
    ExpressionHelpFunction.abs => (
      signature: 'abs(x)',
      description: 'Wartość x bez znaku.',
    ),
    ExpressionHelpFunction.round => (
      signature: 'round(x, miejsca)',
      description:
          'x zaokrąglone do liczby miejsc dziesiętnych podanej w '
          'argumencie miejsca, a bez niego do liczby całkowitej. Ujemny '
          'argument miejsca zaokrągla do dziesiątek, setek…: '
          'round(1234.5, -2) daje 1200.',
    ),
    ExpressionHelpFunction.floor => (
      signature: 'floor(x)',
      description:
          'x zaokrąglone w dół do liczby całkowitej: floor(2.7) daje 2, '
          'floor(-2.5) daje -3.',
    ),
    ExpressionHelpFunction.ceil => (
      signature: 'ceil(x)',
      description:
          'x zaokrąglone w górę do liczby całkowitej: ceil(2.1) daje 3.',
    ),
    ExpressionHelpFunction.sqrt => (
      signature: 'sqrt(x)',
      description: 'Pierwiastek kwadratowy z x; pusty, gdy x jest ujemne.',
    ),
    ExpressionHelpFunction.min => (
      signature: 'min(x, y, …)',
      description: 'Najmniejsza z liczb, z pominięciem pustych.',
    ),
    ExpressionHelpFunction.max => (
      signature: 'max(x, y, …)',
      description: 'Największa z liczb, z pominięciem pustych.',
    ),
    ExpressionHelpFunction.number => (
      signature: 'number(tekst)',
      description:
          'Liczba zapisana w tekście z kropką dziesiętną; pusta, jeśli '
          'tekst nie jest liczbą.',
    ),
    ExpressionHelpFunction.len => (
      signature: 'len(tekst)',
      description: 'Liczba znaków w tekście.',
    ),
    ExpressionHelpFunction.lower => (
      signature: 'lower(tekst)',
      description: 'Tekst zapisany małymi literami.',
    ),
    ExpressionHelpFunction.upper => (
      signature: 'upper(tekst)',
      description: 'Tekst zapisany wielkimi literami.',
    ),
    ExpressionHelpFunction.trim => (
      signature: 'trim(tekst)',
      description: 'Tekst bez spacji na początku i na końcu.',
    ),
    ExpressionHelpFunction.left => (
      signature: 'left(tekst, n)',
      description: 'Pierwsze n znaków tekstu.',
    ),
    ExpressionHelpFunction.right => (
      signature: 'right(tekst, n)',
      description: 'Ostatnie n znaków tekstu.',
    ),
    ExpressionHelpFunction.substring => (
      signature: 'substring(tekst, początek, długość)',
      description:
          'Tyle znaków tekstu, ile wynosi długość, od pozycji początek '
          '(pierwszy znak ma numer 1); bez argumentu długość reszta '
          'tekstu.',
    ),
    ExpressionHelpFunction.contains => (
      signature: 'contains(tekst, fragment)',
      description: 'Prawda, gdy fragment występuje w tekście.',
    ),
    ExpressionHelpFunction.startswith => (
      signature: 'startswith(tekst, fragment)',
      description: 'Prawda, gdy fragment jest na początku tekstu.',
    ),
    ExpressionHelpFunction.endswith => (
      signature: 'endswith(tekst, fragment)',
      description: 'Prawda, gdy fragment jest na końcu tekstu.',
    ),
    ExpressionHelpFunction.replace => (
      signature: 'replace(tekst, stare, nowe)',
      description: 'Tekst, w którym każde stare zastąpiono nowym.',
    ),
    ExpressionHelpFunction.concat => (
      signature: 'concat(a, b, …)',
      description:
          'Połączone teksty, z pominięciem pustych. text(x) zamienia '
          'liczbę lub datę na tekst.',
    ),
    ExpressionHelpFunction.text => (
      signature: 'text(x)',
      description:
          'Liczba, data lub prawda/fałsz jako tekst: text(1.5) daje '
          '"1.5", text(#2024-01-31#) daje "2024-01-31".',
    ),
    ExpressionHelpFunction.year => (
      signature: 'year(data)',
      description: 'Rok z daty.',
    ),
    ExpressionHelpFunction.quarter => (
      signature: 'quarter(data)',
      description: 'Kwartał roku, od 1 do 4.',
    ),
    ExpressionHelpFunction.month => (
      signature: 'month(data)',
      description: 'Miesiąc, od 1 do 12.',
    ),
    ExpressionHelpFunction.week => (
      signature: 'week(data)',
      description: 'Numer tygodnia według ISO, od 1 do 53.',
    ),
    ExpressionHelpFunction.day => (
      signature: 'day(data)',
      description: 'Dzień miesiąca, od 1 do 31.',
    ),
    ExpressionHelpFunction.weekday => (
      signature: 'weekday(data)',
      description: 'Dzień tygodnia, od 1 (poniedziałek) do 7 (niedziela).',
    ),
    ExpressionHelpFunction.hour => (
      signature: 'hour(data)',
      description: 'Godzina, od 0 do 23.',
    ),
    ExpressionHelpFunction.dateOfText => (
      signature: 'date(tekst)',
      description:
          'Data zapisana w tekście, najpierw rok: date("2024-01-31"); '
          'pusta, jeśli tekst nie jest datą.',
    ),
    ExpressionHelpFunction.dateOfParts => (
      signature: 'date(rok, miesiąc, dzień)',
      description: 'Data z podanego roku, miesiąca i dnia.',
    ),
    ExpressionHelpFunction.today => (
      signature: 'today()',
      description: 'Dzisiejsza data.',
    ),
  };
}
