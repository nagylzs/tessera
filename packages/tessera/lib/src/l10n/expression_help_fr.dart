import 'expression_help.dart';

/// fr texts of the expression help. Native review welcome.
final class ExpressionHelpStringsFr extends ExpressionHelpStrings {
  const ExpressionHelpStringsFr();

  @override
  String get languageCode => 'fr';

  @override
  String get title => 'Aide sur les expressions';

  @override
  String get tapToInsert =>
      'Touchez un exemple, une colonne ou une fonction pour l’insérer.';

  @override
  String intro(ExpressionHelpUse use) => switch (use) {
    ExpressionHelpUse.filter =>
      'Un filtre garde les lignes pour lesquelles l’expression est vraie. '
          'Combinez les conditions avec and, or et not.',
    ExpressionHelpUse.measure =>
      'Une mesure calculée est évaluée pour chaque ligne à partir de ses '
          'colonnes, puis on en fait la somme ou la moyenne comme pour une '
          'colonne.',
    ExpressionHelpUse.dimension =>
      'Une dimension calculée regroupe les lignes selon la valeur de '
          'l’expression, comme le ferait une colonne : un nombre, un texte, '
          'une date ou true/false.',
    ExpressionHelpUse.formula =>
      'Une formule de cellule est calculée dans chaque cellule du tableau '
          'croisé à partir des agrégats de la cellule, comme sum(x) ou count.',
  };

  @override
  String get examples => 'Exemples';

  @override
  String get columns => 'Colonnes';

  @override
  String get aggregates => 'Agrégats';

  @override
  String get operators => 'Opérateurs';

  @override
  String get values => 'Valeurs';

  @override
  String get rules => 'Règles';

  @override
  String get functions => 'Fonctions';

  @override
  String get aggregateArgument =>
      'x est une colonne ou un calcul sur les colonnes d’une ligne : '
      'sum(quantity * price). count seul compte les lignes.';

  @override
  String groupName(ExpressionHelpGroup group) => switch (group) {
    ExpressionHelpGroup.conditional => 'Conditions',
    ExpressionHelpGroup.numbers => 'Nombres',
    ExpressionHelpGroup.text => 'Texte',
    ExpressionHelpGroup.dates => 'Dates',
    ExpressionHelpGroup.other => 'Autres fonctions',
  };

  @override
  String operatorText(ExpressionHelpOperator operator) => switch (operator) {
    ExpressionHelpOperator.arithmetic =>
      'Addition, soustraction, multiplication, division. Diviser par zéro '
          'donne une valeur vide.',
    ExpressionHelpOperator.remainder =>
      'Le reste d’une division : 7 % 3 vaut 1.',
    ExpressionHelpOperator.comparison =>
      'Égal, différent, inférieur, inférieur ou égal, supérieur, supérieur '
          'ou égal. == et != fonctionnent aussi.',
    ExpressionHelpOperator.logic =>
      'Les deux conditions, l’une ou l’autre, le contraire.',
    ExpressionHelpOperator.inList =>
      'x est l’une des valeurs listées, ou aucune d’elles.',
    ExpressionHelpOperator.between => 'a ≤ x ≤ b, bornes incluses.',
    ExpressionHelpOperator.emptyTest => 'x n’a pas de valeur, ou en a une.',
    ExpressionHelpOperator.dates =>
      'n jours après ou avant une date ; le nombre de jours entre deux dates.',
  };

  @override
  String literalText(ExpressionHelpLiteral literal) => switch (literal) {
    ExpressionHelpLiteral.number =>
      'Nombres, toujours avec un point décimal : 12.5, pas 12,5.',
    ExpressionHelpLiteral.text =>
      'Texte entre guillemets doubles ou simples. Un guillemet à l’intérieur '
          'est doublé : "say ""hi""".',
    ExpressionHelpLiteral.date =>
      'Dates, avec une heure si besoin, entre deux signes #, l’année en '
          'premier.',
    ExpressionHelpLiteral.boolean => 'Valeurs logiques.',
    ExpressionHelpLiteral.empty => 'La valeur vide.',
    ExpressionHelpLiteral.name =>
      'Un nom de colonne contenant des espaces ou de la ponctuation, ou qui '
          's’écrit comme un mot-clé, se met entre crochets.',
  };

  @override
  String ruleText(ExpressionHelpRule rule) => switch (rule) {
    ExpressionHelpRule.emptyValues =>
      'Un calcul ou une comparaison avec une valeur vide est vide : '
          'price * 2 et price > 0 sont vides là où le prix l’est. '
          'coalesce(price, 0) utilise 0 à la place ; price is empty trouve '
          'les lignes sans prix.',
    ExpressionHelpRule.filters =>
      'Un filtre ne garde une ligne que si son expression est vraie : '
          'discount > 0 écarte les lignes sans remise, '
          'discount > 0 or discount is empty les garde.',
    ExpressionHelpRule.letterCase =>
      'Les noms de fonctions et les mots-clés ne tiennent pas compte de la '
          'casse (YEAR, Year) ; les noms de colonnes doivent correspondre '
          'exactement. Les comparaisons de texte tiennent compte de la '
          'casse : comparez lower(x) pour l’ignorer.',
  };

  @override
  ({String signature, String description}) function(
    ExpressionHelpFunction function,
  ) => switch (function) {
    ExpressionHelpFunction.ifElse => (
      signature: 'if(condition, a, b)',
      description:
          'Là où la condition est vraie, a ; sinon b (y compris là où la '
          'condition est vide). a et b sont du même type.',
    ),
    ExpressionHelpFunction.coalesce => (
      signature: 'coalesce(a, b, …)',
      description: 'Le premier de ses arguments qui n’est pas vide.',
    ),
    ExpressionHelpFunction.isempty => (
      signature: 'isempty(x)',
      description: 'Vrai là où x est vide, comme x is empty.',
    ),
    ExpressionHelpFunction.abs => (
      signature: 'abs(x)',
      description: 'x sans son signe.',
    ),
    ExpressionHelpFunction.round => (
      signature: 'round(x, décimales)',
      description:
          'x arrondi à autant de décimales que l’indique décimales ; sans '
          'décimales, à un nombre entier. Si décimales est négatif, '
          'l’arrondi se fait aux dizaines, centaines… : round(1234.5, -2) '
          'vaut 1200.',
    ),
    ExpressionHelpFunction.floor => (
      signature: 'floor(x)',
      description:
          'x arrondi à l’entier inférieur : floor(2.7) vaut 2, '
          'floor(-2.5) vaut -3.',
    ),
    ExpressionHelpFunction.ceil => (
      signature: 'ceil(x)',
      description: 'x arrondi à l’entier supérieur : ceil(2.1) vaut 3.',
    ),
    ExpressionHelpFunction.sqrt => (
      signature: 'sqrt(x)',
      description: 'La racine carrée de x ; vide pour un x négatif.',
    ),
    ExpressionHelpFunction.min => (
      signature: 'min(x, y, …)',
      description:
          'Le plus petit des nombres, sans tenir compte des valeurs vides.',
    ),
    ExpressionHelpFunction.max => (
      signature: 'max(x, y, …)',
      description:
          'Le plus grand des nombres, sans tenir compte des valeurs vides.',
    ),
    ExpressionHelpFunction.number => (
      signature: 'number(texte)',
      description:
          'Le nombre écrit dans un texte, avec un point décimal ; vide si le '
          'texte n’est pas un nombre.',
    ),
    ExpressionHelpFunction.len => (
      signature: 'len(texte)',
      description: 'Le nombre de caractères du texte.',
    ),
    ExpressionHelpFunction.lower => (
      signature: 'lower(texte)',
      description: 'Le texte en minuscules.',
    ),
    ExpressionHelpFunction.upper => (
      signature: 'upper(texte)',
      description: 'Le texte en majuscules.',
    ),
    ExpressionHelpFunction.trim => (
      signature: 'trim(texte)',
      description: 'Le texte sans les espaces du début et de la fin.',
    ),
    ExpressionHelpFunction.left => (
      signature: 'left(texte, n)',
      description: 'Les n premiers caractères du texte.',
    ),
    ExpressionHelpFunction.right => (
      signature: 'right(texte, n)',
      description: 'Les n derniers caractères du texte.',
    ),
    ExpressionHelpFunction.substring => (
      signature: 'substring(texte, début, longueur)',
      description:
          'longueur caractères du texte à partir de la position début, le '
          'premier caractère étant 1 ; sans longueur, le reste du texte.',
    ),
    ExpressionHelpFunction.contains => (
      signature: 'contains(texte, partie)',
      description: 'Vrai là où partie figure dans le texte.',
    ),
    ExpressionHelpFunction.startswith => (
      signature: 'startswith(texte, partie)',
      description: 'Vrai là où le texte commence par partie.',
    ),
    ExpressionHelpFunction.endswith => (
      signature: 'endswith(texte, partie)',
      description: 'Vrai là où le texte se termine par partie.',
    ),
    ExpressionHelpFunction.replace => (
      signature: 'replace(texte, ancien, nouveau)',
      description: 'Le texte avec chaque ancien remplacé par nouveau.',
    ),
    ExpressionHelpFunction.concat => (
      signature: 'concat(a, b, …)',
      description:
          'Les textes mis bout à bout, sans tenir compte des valeurs vides. '
          'text(x) convertit un nombre ou une date en texte.',
    ),
    ExpressionHelpFunction.text => (
      signature: 'text(x)',
      description:
          'Un nombre, une date ou true/false sous forme de texte : text(1.5) '
          'vaut "1.5", text(#2024-01-31#) vaut "2024-01-31".',
    ),
    ExpressionHelpFunction.year => (
      signature: 'year(date)',
      description: 'L’année de la date.',
    ),
    ExpressionHelpFunction.quarter => (
      signature: 'quarter(date)',
      description: 'Le trimestre de l’année, de 1 à 4.',
    ),
    ExpressionHelpFunction.month => (
      signature: 'month(date)',
      description: 'Le mois, de 1 à 12.',
    ),
    ExpressionHelpFunction.week => (
      signature: 'week(date)',
      description: 'Le numéro de semaine ISO, de 1 à 53.',
    ),
    ExpressionHelpFunction.day => (
      signature: 'day(date)',
      description: 'Le jour du mois, de 1 à 31.',
    ),
    ExpressionHelpFunction.weekday => (
      signature: 'weekday(date)',
      description: 'Le jour de la semaine, de 1 (lundi) à 7 (dimanche).',
    ),
    ExpressionHelpFunction.hour => (
      signature: 'hour(date)',
      description: 'L’heure, de 0 à 23.',
    ),
    ExpressionHelpFunction.dateOfText => (
      signature: 'date(texte)',
      description:
          'La date écrite dans un texte, l’année en premier : '
          'date("2024-01-31") ; vide si le texte n’est pas une date.',
    ),
    ExpressionHelpFunction.dateOfParts => (
      signature: 'date(année, mois, jour)',
      description: 'La date de l’année, du mois et du jour donnés.',
    ),
    ExpressionHelpFunction.today => (
      signature: 'today()',
      description: 'La date du jour.',
    ),
  };
}
