import 'expression_help.dart';

/// cs texts of the expression help. Native review welcome.
final class ExpressionHelpStringsCs extends ExpressionHelpStrings {
  const ExpressionHelpStringsCs();

  @override
  String get languageCode => 'cs';

  @override
  String get title => 'Nápověda k výrazům';

  @override
  String get tapToInsert => 'Klepnutím vložíte příklad, sloupec nebo funkci.';

  @override
  String intro(ExpressionHelpUse use) => switch (use) {
    ExpressionHelpUse.filter =>
      'Filtr ponechá řádky, pro které je výraz pravdivý. Podmínky se '
          'spojují operátory and, or a not.',
    ExpressionHelpUse.measure =>
      'Počítaná míra se vypočítá pro každý řádek z jeho sloupců a '
          'pak se sčítá nebo průměruje jako sloupec.',
    ExpressionHelpUse.dimension =>
      'Počítaná dimenze seskupuje řádky podle hodnoty výrazu, stejně '
          'jako sloupec. Hodnotou může být číslo, text, datum nebo '
          'pravda/nepravda.',
    ExpressionHelpUse.formula =>
      'Vzorec buňky se počítá v každé buňce kontingenční tabulky z '
          'agregátů této buňky, například sum(x) nebo count.',
  };

  @override
  String get examples => 'Příklady';

  @override
  String get columns => 'Sloupce';

  @override
  String get aggregates => 'Agregáty';

  @override
  String get operators => 'Operátory';

  @override
  String get values => 'Hodnoty';

  @override
  String get rules => 'Pravidla';

  @override
  String get functions => 'Funkce';

  @override
  String get aggregateArgument =>
      'x je sloupec nebo výpočet nad sloupci řádku: sum(quantity * '
      'price). Samotné count počítá řádky.';

  @override
  String groupName(ExpressionHelpGroup group) => switch (group) {
    ExpressionHelpGroup.conditional => 'Podmínky',
    ExpressionHelpGroup.numbers => 'Čísla',
    ExpressionHelpGroup.text => 'Text',
    ExpressionHelpGroup.dates => 'Datum a čas',
    ExpressionHelpGroup.other => 'Další funkce',
  };

  @override
  String operatorText(ExpressionHelpOperator operator) => switch (operator) {
    ExpressionHelpOperator.arithmetic =>
      'Sčítání, odčítání, násobení, dělení. Dělení nulou dává '
          'prázdnou hodnotu.',
    ExpressionHelpOperator.remainder => 'Zbytek po dělení: 7 % 3 je 1.',
    ExpressionHelpOperator.comparison =>
      'Rovno, nerovno, menší, menší nebo rovno, větší, větší nebo '
          'rovno. Fungují i == a !=.',
    ExpressionHelpOperator.logic => 'Obě podmínky, kterákoli z nich, opak.',
    ExpressionHelpOperator.inList =>
      'x je jednou z uvedených hodnot, nebo žádnou z nich.',
    ExpressionHelpOperator.between => 'a ≤ x ≤ b, včetně obou krajních hodnot.',
    ExpressionHelpOperator.emptyTest => 'x nemá hodnotu, nebo ji má.',
    ExpressionHelpOperator.dates =>
      'n dní po datu nebo před ním; počet dní mezi dvěma daty.',
  };

  @override
  String literalText(ExpressionHelpLiteral literal) => switch (literal) {
    ExpressionHelpLiteral.number =>
      'Čísla, vždy s desetinnou tečkou: 12.5, ne 12,5.',
    ExpressionHelpLiteral.text =>
      'Text ve dvojitých nebo jednoduchých uvozovkách. Uvozovka '
          'uvnitř textu se zdvojuje: "say ""hi""".',
    ExpressionHelpLiteral.date =>
      'Datum, případně s časem, mezi znaky #, rok na začátku.',
    ExpressionHelpLiteral.boolean => 'Logické hodnoty.',
    ExpressionHelpLiteral.empty => 'Prázdná hodnota.',
    ExpressionHelpLiteral.name =>
      'Název sloupce s mezerami či interpunkcí nebo shodný s '
          'klíčovým slovem se píše do hranatých závorek.',
  };

  @override
  String ruleText(ExpressionHelpRule rule) => switch (rule) {
    ExpressionHelpRule.emptyValues =>
      'Výpočet nebo porovnání s prázdnou hodnotou je prázdné: price '
          '* 2 a price > 0 jsou prázdné tam, kde je prázdný sloupec '
          'price. coalesce(price, 0) místo prázdné hodnoty použije 0; '
          'price is empty najde řádky bez ceny.',
    ExpressionHelpRule.filters =>
      'Filtr ponechá řádek jen tehdy, je-li jeho výraz pravdivý: '
          'discount > 0 vyřadí řádky bez slevy, discount > 0 or discount '
          'is empty je ponechá.',
    ExpressionHelpRule.letterCase =>
      'Názvy funkcí a klíčová slova lze psát velkými i malými '
          'písmeny (YEAR, Year); názvy sloupců se musí shodovat přesně. '
          'Porovnání textu rozlišuje velikost písmen: chcete-li ji '
          'ignorovat, porovnávejte lower(x).',
  };

  @override
  ({String signature, String description}) function(
    ExpressionHelpFunction function,
  ) => switch (function) {
    ExpressionHelpFunction.ifElse => (
      signature: 'if(podmínka, a, b)',
      description:
          'Hodnota a, je-li podmínka pravdivá, jinak b (i když je '
          'podmínka prázdná). Argumenty a, b mají stejný typ.',
    ),
    ExpressionHelpFunction.coalesce => (
      signature: 'coalesce(a, b, …)',
      description: 'První z argumentů, který není prázdný.',
    ),
    ExpressionHelpFunction.isempty => (
      signature: 'isempty(x)',
      description: 'Pravda, je-li x prázdné; totéž co x is empty.',
    ),
    ExpressionHelpFunction.abs => (
      signature: 'abs(x)',
      description: 'Hodnota x bez znaménka.',
    ),
    ExpressionHelpFunction.round => (
      signature: 'round(x, místa)',
      description:
          'x zaokrouhlené na počet desetinných míst daný argumentem '
          'místa, bez něj na celé číslo. Záporný argument místa '
          'zaokrouhluje na desítky, stovky…: round(1234.5, -2) je 1200.',
    ),
    ExpressionHelpFunction.floor => (
      signature: 'floor(x)',
      description:
          'x zaokrouhlené dolů na celé číslo: floor(2.7) je 2, '
          'floor(-2.5) je -3.',
    ),
    ExpressionHelpFunction.ceil => (
      signature: 'ceil(x)',
      description: 'x zaokrouhlené nahoru na celé číslo: ceil(2.1) je 3.',
    ),
    ExpressionHelpFunction.sqrt => (
      signature: 'sqrt(x)',
      description: 'Druhá odmocnina z x; prázdná, je-li x záporné.',
    ),
    ExpressionHelpFunction.min => (
      signature: 'min(x, y, …)',
      description: 'Nejmenší z čísel; prázdná se vynechávají.',
    ),
    ExpressionHelpFunction.max => (
      signature: 'max(x, y, …)',
      description: 'Největší z čísel; prázdná se vynechávají.',
    ),
    ExpressionHelpFunction.number => (
      signature: 'number(text)',
      description:
          'Číslo zapsané v textu s desetinnou tečkou; prázdné, pokud '
          'text není číslo.',
    ),
    ExpressionHelpFunction.len => (
      signature: 'len(text)',
      description: 'Počet znaků v textu.',
    ),
    ExpressionHelpFunction.lower => (
      signature: 'lower(text)',
      description: 'Text malými písmeny.',
    ),
    ExpressionHelpFunction.upper => (
      signature: 'upper(text)',
      description: 'Text velkými písmeny.',
    ),
    ExpressionHelpFunction.trim => (
      signature: 'trim(text)',
      description: 'Text bez mezer na začátku a na konci.',
    ),
    ExpressionHelpFunction.left => (
      signature: 'left(text, n)',
      description: 'Prvních n znaků textu.',
    ),
    ExpressionHelpFunction.right => (
      signature: 'right(text, n)',
      description: 'Posledních n znaků textu.',
    ),
    ExpressionHelpFunction.substring => (
      signature: 'substring(text, začátek, délka)',
      description:
          'Tolik znaků textu, kolik udává délka, od pozice začátek '
          '(první znak je 1); bez argumentu délka zbytek textu.',
    ),
    ExpressionHelpFunction.contains => (
      signature: 'contains(text, část)',
      description: 'Pravda, vyskytuje-li se část v textu.',
    ),
    ExpressionHelpFunction.startswith => (
      signature: 'startswith(text, část)',
      description: 'Pravda, je-li část na začátku textu.',
    ),
    ExpressionHelpFunction.endswith => (
      signature: 'endswith(text, část)',
      description: 'Pravda, je-li část na konci textu.',
    ),
    ExpressionHelpFunction.replace => (
      signature: 'replace(text, staré, nové)',
      description: 'Text, v němž je každé staré nahrazeno novým.',
    ),
    ExpressionHelpFunction.concat => (
      signature: 'concat(a, b, …)',
      description:
          'Spojené texty; prázdné se vynechávají. text(x) převede číslo '
          'nebo datum na text.',
    ),
    ExpressionHelpFunction.text => (
      signature: 'text(x)',
      description:
          'Číslo, datum nebo pravda/nepravda jako text: text(1.5) je '
          '"1.5", text(#2024-01-31#) je "2024-01-31".',
    ),
    ExpressionHelpFunction.year => (
      signature: 'year(datum)',
      description: 'Rok data.',
    ),
    ExpressionHelpFunction.quarter => (
      signature: 'quarter(datum)',
      description: 'Čtvrtletí roku, 1 až 4.',
    ),
    ExpressionHelpFunction.month => (
      signature: 'month(datum)',
      description: 'Měsíc, 1 až 12.',
    ),
    ExpressionHelpFunction.week => (
      signature: 'week(datum)',
      description: 'Číslo týdne podle ISO, 1 až 53.',
    ),
    ExpressionHelpFunction.day => (
      signature: 'day(datum)',
      description: 'Den v měsíci, 1 až 31.',
    ),
    ExpressionHelpFunction.weekday => (
      signature: 'weekday(datum)',
      description: 'Den v týdnu, 1 (pondělí) až 7 (neděle).',
    ),
    ExpressionHelpFunction.hour => (
      signature: 'hour(datum)',
      description: 'Hodina, 0 až 23.',
    ),
    ExpressionHelpFunction.dateOfText => (
      signature: 'date(text)',
      description:
          'Datum zapsané v textu, rok na začátku: date("2024-01-31"); '
          'prázdné, pokud text není datum.',
    ),
    ExpressionHelpFunction.dateOfParts => (
      signature: 'date(rok, měsíc, den)',
      description: 'Datum ze zadaného roku, měsíce a dne.',
    ),
    ExpressionHelpFunction.today => (
      signature: 'today()',
      description: 'Dnešní datum.',
    ),
  };
}
