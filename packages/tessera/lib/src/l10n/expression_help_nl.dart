import 'expression_help.dart';

/// nl texts of the expression help. Native review welcome.
final class ExpressionHelpStringsNl extends ExpressionHelpStrings {
  const ExpressionHelpStringsNl();

  @override
  String get languageCode => 'nl';

  @override
  String get title => 'Hulp bij expressies';

  @override
  String get tapToInsert =>
      'Tik op een voorbeeld, een kolom of een functie om die in te voegen.';

  @override
  String intro(ExpressionHelpUse use) => switch (use) {
    ExpressionHelpUse.filter =>
      'Een filter behoudt de rijen waarvoor de expressie waar is. '
          'Combineer voorwaarden met and, or en not.',
    ExpressionHelpUse.measure =>
      'Een berekende meetwaarde wordt voor elke rij uit de kolommen van die '
          'rij berekend en daarna net als een kolom opgeteld of gemiddeld.',
    ExpressionHelpUse.dimension =>
      'Een berekende dimensie groepeert de rijen net als een kolom op de '
          'waarde van de expressie: een getal, een tekst, een datum of '
          'waar/onwaar.',
    ExpressionHelpUse.formula =>
      'Een celformule wordt in elke cel van de draaitabel berekend uit de '
          'aggregaten van die cel, zoals sum(x) of count.',
  };

  @override
  String get examples => 'Voorbeelden';

  @override
  String get columns => 'Kolommen';

  @override
  String get aggregates => 'Aggregaten';

  @override
  String get operators => 'Operatoren';

  @override
  String get values => 'Waarden';

  @override
  String get rules => 'Regels';

  @override
  String get functions => 'Functies';

  @override
  String get aggregateArgument =>
      'x is een kolom of een berekening over de kolommen van een rij: '
      'sum(quantity * price). count alleen telt de rijen.';

  @override
  String groupName(ExpressionHelpGroup group) => switch (group) {
    ExpressionHelpGroup.conditional => 'Voorwaarden',
    ExpressionHelpGroup.numbers => 'Getallen',
    ExpressionHelpGroup.text => 'Tekst',
    ExpressionHelpGroup.dates => 'Datum en tijd',
    ExpressionHelpGroup.other => 'Extra functies',
  };

  @override
  String operatorText(ExpressionHelpOperator operator) => switch (operator) {
    ExpressionHelpOperator.arithmetic =>
      'Optellen, aftrekken, vermenigvuldigen, delen. Delen door nul geeft '
          'een lege waarde.',
    ExpressionHelpOperator.remainder => 'De rest van een deling: 7 % 3 is 1.',
    ExpressionHelpOperator.comparison =>
      'Gelijk, ongelijk, kleiner, kleiner of gelijk, groter, groter of '
          'gelijk. == en != werken ook.',
    ExpressionHelpOperator.logic =>
      'Beide voorwaarden, minstens één ervan, het tegendeel.',
    ExpressionHelpOperator.inList =>
      'x is een van de genoemde waarden, of geen ervan.',
    ExpressionHelpOperator.between => 'a ≤ x ≤ b, beide grenzen inbegrepen.',
    ExpressionHelpOperator.emptyTest => 'x heeft geen waarde, of heeft er een.',
    ExpressionHelpOperator.dates =>
      'n dagen na of voor een datum; het aantal dagen tussen twee datums.',
  };

  @override
  String literalText(ExpressionHelpLiteral literal) => switch (literal) {
    ExpressionHelpLiteral.number =>
      'Getallen, altijd met een decimale punt: 12.5, niet 12,5.',
    ExpressionHelpLiteral.text =>
      'Tekst tussen dubbele of enkele aanhalingstekens. Een aanhalingsteken '
          'erbinnen wordt verdubbeld: "say ""hi""".',
    ExpressionHelpLiteral.date =>
      'Datums, zo nodig met een tijd, tussen #-tekens, het jaar eerst.',
    ExpressionHelpLiteral.boolean => 'Logische waarden.',
    ExpressionHelpLiteral.empty => 'De lege waarde.',
    ExpressionHelpLiteral.name =>
      'Een kolomnaam met spaties of leestekens, of een die als een '
          'sleutelwoord gespeld is, staat tussen vierkante haken.',
  };

  @override
  String ruleText(ExpressionHelpRule rule) => switch (rule) {
    ExpressionHelpRule.emptyValues =>
      'Een berekening of vergelijking met een lege waarde is leeg: '
          'price * 2 en price > 0 zijn leeg waar de prijs leeg is. '
          'coalesce(price, 0) gebruikt dan 0; price is empty vindt de rijen '
          'zonder prijs.',
    ExpressionHelpRule.filters =>
      'Een filter behoudt een rij alleen als zijn expressie waar is: '
          'discount > 0 laat de rijen zonder korting weg, '
          'discount > 0 or discount is empty behoudt ze.',
    ExpressionHelpRule.letterCase =>
      'Functienamen en sleutelwoorden mogen met hoofd- of kleine letters '
          'geschreven worden (YEAR, Year); kolomnamen moeten exact '
          'overeenkomen. Tekstvergelijkingen zijn hoofdlettergevoelig: '
          'vergelijk lower(x) om hoofdletters te negeren.',
  };

  @override
  ({String signature, String description}) function(
    ExpressionHelpFunction function,
  ) => switch (function) {
    ExpressionHelpFunction.ifElse => (
      signature: 'if(voorwaarde, a, b)',
      description:
          'a als de voorwaarde waar is, anders b (ook als de voorwaarde '
          'leeg is). a en b zijn van hetzelfde type.',
    ),
    ExpressionHelpFunction.coalesce => (
      signature: 'coalesce(a, b, …)',
      description: 'Het eerste argument dat niet leeg is.',
    ),
    ExpressionHelpFunction.isempty => (
      signature: 'isempty(x)',
      description: 'Waar als x leeg is, hetzelfde als x is empty.',
    ),
    ExpressionHelpFunction.abs => (
      signature: 'abs(x)',
      description: 'x zonder teken.',
    ),
    ExpressionHelpFunction.round => (
      signature: 'round(x, cijfers)',
      description:
          'x afgerond op cijfers decimalen, zonder cijfers op een geheel '
          'getal. Met negatieve cijfers wordt afgerond op tientallen, '
          'honderdtallen…: round(1234.5, -2) is 1200.',
    ),
    ExpressionHelpFunction.floor => (
      signature: 'floor(x)',
      description:
          'x naar beneden afgerond op een geheel getal: floor(2.7) is 2, '
          'floor(-2.5) is -3.',
    ),
    ExpressionHelpFunction.ceil => (
      signature: 'ceil(x)',
      description: 'x naar boven afgerond op een geheel getal: ceil(2.1) is 3.',
    ),
    ExpressionHelpFunction.sqrt => (
      signature: 'sqrt(x)',
      description: 'De vierkantswortel van x; leeg bij een negatieve x.',
    ),
    ExpressionHelpFunction.min => (
      signature: 'min(x, y, …)',
      description: 'Het kleinste van de getallen; lege tellen niet mee.',
    ),
    ExpressionHelpFunction.max => (
      signature: 'max(x, y, …)',
      description: 'Het grootste van de getallen; lege tellen niet mee.',
    ),
    ExpressionHelpFunction.number => (
      signature: 'number(tekst)',
      description:
          'Het getal dat in een tekst staat, met een decimale punt; leeg als '
          'de tekst geen getal is.',
    ),
    ExpressionHelpFunction.len => (
      signature: 'len(tekst)',
      description: 'Het aantal tekens in de tekst.',
    ),
    ExpressionHelpFunction.lower => (
      signature: 'lower(tekst)',
      description: 'De tekst in kleine letters.',
    ),
    ExpressionHelpFunction.upper => (
      signature: 'upper(tekst)',
      description: 'De tekst in hoofdletters.',
    ),
    ExpressionHelpFunction.trim => (
      signature: 'trim(tekst)',
      description: 'De tekst zonder spaties aan het begin en het einde.',
    ),
    ExpressionHelpFunction.left => (
      signature: 'left(tekst, n)',
      description: 'De eerste n tekens van de tekst.',
    ),
    ExpressionHelpFunction.right => (
      signature: 'right(tekst, n)',
      description: 'De laatste n tekens van de tekst.',
    ),
    ExpressionHelpFunction.substring => (
      signature: 'substring(tekst, begin, lengte)',
      description:
          'lengte tekens van de tekst vanaf positie begin, waarbij het eerste '
          'teken 1 is; zonder lengte de rest van de tekst.',
    ),
    ExpressionHelpFunction.contains => (
      signature: 'contains(tekst, deel)',
      description: 'Waar als deel in de tekst voorkomt.',
    ),
    ExpressionHelpFunction.startswith => (
      signature: 'startswith(tekst, deel)',
      description: 'Waar als de tekst met deel begint.',
    ),
    ExpressionHelpFunction.endswith => (
      signature: 'endswith(tekst, deel)',
      description: 'Waar als de tekst op deel eindigt.',
    ),
    ExpressionHelpFunction.replace => (
      signature: 'replace(tekst, oud, nieuw)',
      description: 'De tekst waarin elk oud door nieuw is vervangen.',
    ),
    ExpressionHelpFunction.concat => (
      signature: 'concat(a, b, …)',
      description:
          'De teksten samengevoegd; lege tellen niet mee. text(x) maakt van '
          'een getal of een datum tekst.',
    ),
    ExpressionHelpFunction.text => (
      signature: 'text(x)',
      description:
          'Een getal, een datum of waar/onwaar als tekst: text(1.5) is '
          '"1.5", text(#2024-01-31#) is "2024-01-31".',
    ),
    ExpressionHelpFunction.year => (
      signature: 'year(datum)',
      description: 'Het jaar van de datum.',
    ),
    ExpressionHelpFunction.quarter => (
      signature: 'quarter(datum)',
      description: 'Het kwartaal van het jaar, 1 tot en met 4.',
    ),
    ExpressionHelpFunction.month => (
      signature: 'month(datum)',
      description: 'De maand, 1 tot en met 12.',
    ),
    ExpressionHelpFunction.week => (
      signature: 'week(datum)',
      description: 'Het ISO-weeknummer, 1 tot en met 53.',
    ),
    ExpressionHelpFunction.day => (
      signature: 'day(datum)',
      description: 'De dag van de maand, 1 tot en met 31.',
    ),
    ExpressionHelpFunction.weekday => (
      signature: 'weekday(datum)',
      description: 'De dag van de week, 1 (maandag) tot en met 7 (zondag).',
    ),
    ExpressionHelpFunction.hour => (
      signature: 'hour(datum)',
      description: 'Het uur van de tijd, 0 tot en met 23.',
    ),
    ExpressionHelpFunction.dateOfText => (
      signature: 'date(tekst)',
      description:
          'De datum die in een tekst staat, het jaar eerst: '
          'date("2024-01-31"); leeg als de tekst geen datum is.',
    ),
    ExpressionHelpFunction.dateOfParts => (
      signature: 'date(jaar, maand, dag)',
      description: 'De datum uit het opgegeven jaar, de maand en de dag.',
    ),
    ExpressionHelpFunction.today => (
      signature: 'today()',
      description: 'De datum van vandaag.',
    ),
  };
}
