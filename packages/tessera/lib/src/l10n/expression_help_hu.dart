import 'expression_help.dart';

/// hu texts of the expression help. Native review welcome.
final class ExpressionHelpStringsHu extends ExpressionHelpStrings {
  const ExpressionHelpStringsHu();

  @override
  String get languageCode => 'hu';

  @override
  String get title => 'Súgó a kifejezésekhez';

  @override
  String get tapToInsert =>
      'Egy példára, oszlopra vagy függvényre koppintva beilleszthető.';

  @override
  String intro(ExpressionHelpUse use) => switch (use) {
    ExpressionHelpUse.filter =>
      'A szűrő azokat a rekordokat tartja meg, amelyekre a kifejezés '
          'igaz. Feltételek összekapcsolása: and, or, not.',
    ExpressionHelpUse.measure =>
      'A számított érték minden rekordra kiszámolódik a rekord '
          'oszlopaiból, majd egy oszlophoz hasonlóan összegezhető vagy '
          'átlagolható.',
    ExpressionHelpUse.dimension =>
      'A számított dimenzió a kifejezés értéke szerint csoportosítja a '
          'rekordokat, ahogy egy oszlop tenné: szám, szöveg, dátum vagy '
          'igaz/hamis.',
    ExpressionHelpUse.formula =>
      'A cellaképlet a kimutatás minden cellájában kiszámolódik a cella '
          'aggregátumaiból, például sum(x) vagy count.',
  };

  @override
  String get examples => 'Példák';

  @override
  String get columns => 'Oszlopok';

  @override
  String get aggregates => 'Aggregátumok';

  @override
  String get operators => 'Műveletek';

  @override
  String get values => 'Értékek';

  @override
  String get rules => 'Szabályok';

  @override
  String get functions => 'Függvények';

  @override
  String get aggregateArgument =>
      'x egy oszlop vagy egy rekord oszlopaiból számolt érték: '
      'sum(quantity * price). A count magában a rekordokat számolja.';

  @override
  String groupName(ExpressionHelpGroup group) => switch (group) {
    ExpressionHelpGroup.conditional => 'Feltételek',
    ExpressionHelpGroup.numbers => 'Számok',
    ExpressionHelpGroup.text => 'Szöveg',
    ExpressionHelpGroup.dates => 'Dátumok',
    ExpressionHelpGroup.other => 'További függvények',
  };

  @override
  String operatorText(ExpressionHelpOperator operator) => switch (operator) {
    ExpressionHelpOperator.arithmetic =>
      'Összeadás, kivonás, szorzás, osztás. A nullával osztás eredménye '
          'üres érték.',
    ExpressionHelpOperator.remainder => 'Az osztás maradéka: 7 % 3 = 1.',
    ExpressionHelpOperator.comparison =>
      'Egyenlő, nem egyenlő, kisebb, kisebb vagy egyenlő, nagyobb, '
          'nagyobb vagy egyenlő. Az == és a != is használható.',
    ExpressionHelpOperator.logic =>
      'Mindkét feltétel, valamelyik feltétel, az ellentéte.',
    ExpressionHelpOperator.inList =>
      'x a felsorolt értékek egyike, illetve egyike sem.',
    ExpressionHelpOperator.between => 'a ≤ x ≤ b, a határokat is beleértve.',
    ExpressionHelpOperator.emptyTest => 'x-nek nincs értéke, illetve van.',
    ExpressionHelpOperator.dates =>
      'n nappal egy dátum után vagy előtt; két dátum között eltelt napok.',
  };

  @override
  String literalText(ExpressionHelpLiteral literal) => switch (literal) {
    ExpressionHelpLiteral.number =>
      'Számok, mindig tizedesponttal: 12.5, nem 12,5.',
    ExpressionHelpLiteral.text =>
      'Szöveg idézőjelek vagy aposztrófok között. A szövegen belüli '
          'idézőjel duplán írandó: "say ""hi""".',
    ExpressionHelpLiteral.date =>
      'Dátum, ha kell, időponttal, # jelek között, az évvel kezdve.',
    ExpressionHelpLiteral.boolean => 'Logikai értékek (igaz, hamis).',
    ExpressionHelpLiteral.empty => 'Az üres érték.',
    ExpressionHelpLiteral.name =>
      'Szóközt, írásjelet tartalmazó vagy kulcsszóval egyező oszlopnév '
          'szögletes zárójelbe kerül.',
  };

  @override
  String ruleText(ExpressionHelpRule rule) => switch (rule) {
    ExpressionHelpRule.emptyValues =>
      'Üres értékkel számolva vagy összehasonlítva az eredmény üres: '
          'a price * 2 és a price > 0 is üres, ahol az ár üres. A '
          'coalesce(price, 0) ilyenkor 0-t ad, a price is empty pedig '
          'megtalálja az ár nélküli rekordokat.',
    ExpressionHelpRule.filters =>
      'A szűrő csak azt a rekordot tartja meg, amelyre a kifejezés igaz: '
          'a discount > 0 elhagyja a kedvezmény nélküli rekordokat, a '
          'discount > 0 or discount is empty megtartja őket.',
    ExpressionHelpRule.letterCase =>
      'A függvénynevek és a kulcsszavak kis- és nagybetűvel is írhatók '
          '(YEAR, Year); az oszlopnévnek pontosan egyeznie kell. A '
          'szövegek összehasonlítása megkülönbözteti a kis- és '
          'nagybetűt; a lower(x) összevetése ezt kikerüli.',
  };

  @override
  ({String signature, String description}) function(
    ExpressionHelpFunction function,
  ) => switch (function) {
    ExpressionHelpFunction.ifElse => (
      signature: 'if(feltétel, a, b)',
      description:
          'a, ahol a feltétel igaz, egyébként b (akkor is, ha a feltétel '
          'üres). a és b azonos típusú.',
    ),
    ExpressionHelpFunction.coalesce => (
      signature: 'coalesce(a, b, …)',
      description: 'Az első nem üres paraméter.',
    ),
    ExpressionHelpFunction.isempty => (
      signature: 'isempty(x)',
      description: 'Igaz, ahol x üres; ugyanaz, mint x is empty.',
    ),
    ExpressionHelpFunction.abs => (
      signature: 'abs(x)',
      description: 'x előjel nélkül (abszolút érték).',
    ),
    ExpressionHelpFunction.round => (
      signature: 'round(x, jegyek)',
      description:
          'x kerekítve jegyek tizedesjegyre, jegyek nélkül egészre. '
          'Negatív jegyek tízesekre, százasokra… kerekít: '
          'round(1234.5, -2) = 1200.',
    ),
    ExpressionHelpFunction.floor => (
      signature: 'floor(x)',
      description:
          'x lefelé kerekítve egészre: floor(2.7) = 2, floor(-2.5) = -3.',
    ),
    ExpressionHelpFunction.ceil => (
      signature: 'ceil(x)',
      description: 'x felfelé kerekítve egészre: ceil(2.1) = 3.',
    ),
    ExpressionHelpFunction.sqrt => (
      signature: 'sqrt(x)',
      description: 'x négyzetgyöke; negatív x-re üres.',
    ),
    ExpressionHelpFunction.min => (
      signature: 'min(x, y, …)',
      description: 'A legkisebb szám, az üreseket kihagyva.',
    ),
    ExpressionHelpFunction.max => (
      signature: 'max(x, y, …)',
      description: 'A legnagyobb szám, az üreseket kihagyva.',
    ),
    ExpressionHelpFunction.number => (
      signature: 'number(szöveg)',
      description:
          'A szövegben tizedesponttal leírt szám; üres, ha a szöveg nem '
          'szám.',
    ),
    ExpressionHelpFunction.len => (
      signature: 'len(szöveg)',
      description: 'A szöveg karaktereinek száma.',
    ),
    ExpressionHelpFunction.lower => (
      signature: 'lower(szöveg)',
      description: 'A szöveg kisbetűsen.',
    ),
    ExpressionHelpFunction.upper => (
      signature: 'upper(szöveg)',
      description: 'A szöveg nagybetűsen.',
    ),
    ExpressionHelpFunction.trim => (
      signature: 'trim(szöveg)',
      description: 'A szöveg az elején és a végén álló szóközök nélkül.',
    ),
    ExpressionHelpFunction.left => (
      signature: 'left(szöveg, n)',
      description: 'A szöveg első n karaktere.',
    ),
    ExpressionHelpFunction.right => (
      signature: 'right(szöveg, n)',
      description: 'A szöveg utolsó n karaktere.',
    ),
    ExpressionHelpFunction.substring => (
      signature: 'substring(szöveg, kezdet, hossz)',
      description:
          'A szöveg hossz darab karaktere a kezdet pozíciótól, az első '
          'karakter az 1-es; hossz nélkül a szöveg hátralévő része.',
    ),
    ExpressionHelpFunction.contains => (
      signature: 'contains(szöveg, rész)',
      description: 'Igaz, ahol a rész előfordul a szövegben.',
    ),
    ExpressionHelpFunction.startswith => (
      signature: 'startswith(szöveg, rész)',
      description: 'Igaz, ahol a szöveg a résszel kezdődik.',
    ),
    ExpressionHelpFunction.endswith => (
      signature: 'endswith(szöveg, rész)',
      description: 'Igaz, ahol a szöveg a résszel végződik.',
    ),
    ExpressionHelpFunction.replace => (
      signature: 'replace(szöveg, régi, új)',
      description: 'A szöveg, benne minden régi helyett új.',
    ),
    ExpressionHelpFunction.concat => (
      signature: 'concat(a, b, …)',
      description:
          'A szövegek egybefűzve, az üreseket kihagyva. A text(x) számot '
          'vagy dátumot alakít szöveggé.',
    ),
    ExpressionHelpFunction.text => (
      signature: 'text(x)',
      description:
          'Szám, dátum vagy igaz/hamis szövegként: text(1.5) = "1.5", '
          'text(#2024-01-31#) = "2024-01-31".',
    ),
    ExpressionHelpFunction.year => (
      signature: 'year(dátum)',
      description: 'A dátum éve.',
    ),
    ExpressionHelpFunction.quarter => (
      signature: 'quarter(dátum)',
      description: 'A negyedév, 1–4.',
    ),
    ExpressionHelpFunction.month => (
      signature: 'month(dátum)',
      description: 'A hónap, 1–12.',
    ),
    ExpressionHelpFunction.week => (
      signature: 'week(dátum)',
      description: 'Az ISO hét sorszáma, 1–53.',
    ),
    ExpressionHelpFunction.day => (
      signature: 'day(dátum)',
      description: 'A hónap napja, 1–31.',
    ),
    ExpressionHelpFunction.weekday => (
      signature: 'weekday(dátum)',
      description: 'A hét napja, 1 (hétfő) – 7 (vasárnap).',
    ),
    ExpressionHelpFunction.hour => (
      signature: 'hour(dátum)',
      description: 'Az időpont órája, 0–23.',
    ),
    ExpressionHelpFunction.dateOfText => (
      signature: 'date(szöveg)',
      description:
          'A szövegben az évvel kezdve leírt dátum: date("2024-01-31"); '
          'üres, ha a szöveg nem dátum.',
    ),
    ExpressionHelpFunction.dateOfParts => (
      signature: 'date(év, hónap, nap)',
      description: 'A megadott év, hónap és nap dátuma.',
    ),
    ExpressionHelpFunction.today => (
      signature: 'today()',
      description: 'A mai dátum.',
    ),
  };
}
