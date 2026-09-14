import '../cube/layout_aggregate.dart';
import '../expr/expr_type.dart';
import '../expr/expression_error.dart';
import '../facts/dimension.dart';
import 'tessera_strings.dart';

/// fr texts. Native review welcome.
final class TesseraStringsFr extends TesseraStrings {
  const TesseraStringsFr();

  @override
  String get languageCode => 'fr';

  @override
  String sumOf(String t) => 'somme de $t';

  @override
  String averageOf(String t) => 'moyenne de $t';

  @override
  String minimumOf(String t) => 'minimum de $t';

  @override
  String maximumOf(String t) => 'maximum de $t';

  @override
  String stdDevOf(String t) => 'écart-type de $t';

  @override
  String stdDevPopulationOf(String t) => 'écart-type (population) de $t';

  @override
  String varianceOf(String t) => 'variance de $t';

  @override
  String variancePopulationOf(String t) => 'variance (population) de $t';

  @override
  String countOf(String t) => 'nombre de $t';

  @override
  String distinctCountOf(String t) => 'valeurs distinctes de $t';

  @override
  String get countLabel => 'nombre';

  @override
  String percentOfTotal(String base, TotalOf of) => switch (of) {
    TotalOf.row => '$base % du total de la ligne',
    TotalOf.column => '$base % du total de la colonne',
    TotalOf.grand => '$base % du total général',
    TotalOf.parentRow => '$base % de la ligne parente',
    TotalOf.parentColumn => '$base % de la colonne parente',
  };

  @override
  String differenceFrom(String base, String item, {required bool percent}) =>
      percent
      ? '$base % de différence par rapport à $item'
      : '$base différence par rapport à $item';

  @override
  String get previousItem => 'précédent';

  @override
  String get nextItem => 'suivant';

  @override
  String runningTotalOf(String base) => '$base cumul';

  @override
  String rankOf(String base) => '$base rang';

  @override
  String get showValuesAs => 'Afficher les valeurs comme';

  @override
  String valueDisplayName(ValueDisplay display) => switch (display) {
    ValueDisplay.plain => 'Valeur simple',
    ValueDisplay.percentOfRow => '% du total de la ligne',
    ValueDisplay.percentOfColumn => '% du total de la colonne',
    ValueDisplay.percentOfGrand => '% du total général',
    ValueDisplay.percentOfParentRow => '% de la ligne parente',
    ValueDisplay.percentOfParentColumn => '% de la colonne parente',
    ValueDisplay.differenceFromPreviousRow =>
      'Différence par rapport à la ligne précédente',
    ValueDisplay.differenceFromPreviousColumn =>
      'Différence par rapport à la colonne précédente',
    ValueDisplay.percentDifferenceFromPreviousRow =>
      '% de différence par rapport à la ligne précédente',
    ValueDisplay.percentDifferenceFromPreviousColumn =>
      '% de différence par rapport à la colonne précédente',
    ValueDisplay.runningTotalRows => 'Cumul par lignes',
    ValueDisplay.runningTotalColumns => 'Cumul par colonnes',
    ValueDisplay.rankRows => 'Rang parmi les lignes',
    ValueDisplay.rankColumns => 'Rang parmi les colonnes',
  };

  @override
  String get formula => 'Formule';

  @override
  String get labelField => 'Libellé';

  @override
  String get countOfFacts => 'Nombre de lignes';

  @override
  String get sum => 'Somme';

  @override
  String get average => 'Moyenne';

  @override
  String get minimum => 'Minimum';

  @override
  String get maximum => 'Maximum';

  @override
  String get standardDeviation => 'Écart-type';

  @override
  String get populationStandardDeviation => 'Écart-type (population)';

  @override
  String get variance => 'Variance';

  @override
  String get populationVariance => 'Variance (population)';

  @override
  String get countOfValues => 'Nombre de valeurs';

  @override
  String get distinctCount => 'Nombre de valeurs distinctes';

  @override
  String datePartName(DatePart part) => switch (part) {
    DatePart.year => 'année',
    DatePart.quarter => 'trimestre',
    DatePart.month => 'mois',
    DatePart.week => 'semaine',
    DatePart.day => 'jour',
    DatePart.weekday => 'jour de la semaine',
    DatePart.hour => 'heure',
  };

  @override
  String datePartLabel(String column, DatePart part) {
    final p = datePartName(part);
    return '$column $p';
  }

  static const _months = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];

  static const _weekdays = [
    'lundi',
    'mardi',
    'mercredi',
    'jeudi',
    'vendredi',
    'samedi',
    'dimanche',
  ];

  @override
  String monthName(int month) => _months[month - 1];

  @override
  String weekdayName(int weekday) => _weekdays[weekday - 1];

  @override
  String quarter(int q) => 'T$q';

  @override
  String get decimalSeparator => ',';

  @override
  String get groupSeparator => '\u00A0';

  @override
  String get rows => 'Lignes';

  @override
  String get columns => 'Colonnes';

  @override
  String get values => 'Valeurs';

  @override
  String get emptyGroup => '(vide)';

  @override
  String get total => 'Total';

  @override
  String get dropDimensionsHere => 'Déposez les dimensions ici';

  @override
  String get addDimension => 'Ajouter une dimension';

  @override
  String get addAggregate => 'Ajouter un agrégat';

  @override
  String get search => 'Rechercher';

  @override
  String get alreadyInUse => 'déjà utilisé';

  @override
  String get function => 'Fonction';

  @override
  String get expand => 'Développer';

  @override
  String get largeExpansionTitle => 'Développement important';

  @override
  String get sortAscending => 'Trier par ordre croissant';

  @override
  String get sortDescending => 'Trier par ordre décroissant';

  @override
  String get inheritSort => 'Même ordre que le niveau supérieur';

  @override
  String get totalsAtEnd => 'Totaux à la fin';

  @override
  String get totalsAtStart => 'Totaux au début';

  @override
  String get totalsHidden => 'Masquer les totaux';

  @override
  String get subtotalsAbove => 'Sous-totaux au-dessus du groupe';

  @override
  String get subtotalsBelow => 'Sous-totaux sous le groupe';

  @override
  String get subtotalsLeft => 'Sous-totaux à gauche du groupe';

  @override
  String get subtotalsRight => 'Sous-totaux à droite du groupe';

  @override
  String get subtotalsHidden => 'Masquer les sous-totaux';

  @override
  String get expandAll => 'Tout développer';

  @override
  String get collapseAll => 'Tout réduire';

  @override
  String largeExpansion(String label, int added, {required bool isRow}) =>
      'Développer « $label » ajoute $added ${isRow ? 'lignes' : 'colonnes'}. Continuer ?';

  @override
  String get filter => 'Filtre';

  @override
  String get noFilter => 'Aucun filtre';

  @override
  String get addCondition => 'Ajouter une condition';

  @override
  String get addGroup => 'Ajouter un groupe';

  @override
  String get addExpression => 'Ajouter une expression';

  @override
  String get matchAll => 'Toutes les conditions';

  @override
  String get matchAny => 'Au moins une condition';

  @override
  String get negate => 'Non';

  @override
  String get opEquals => 'est égal à';

  @override
  String get opNotEquals => 'est différent de';

  @override
  String get opLess => 'est inférieur à';

  @override
  String get opLessOrEqual => 'est au plus';

  @override
  String get opGreater => 'est supérieur à';

  @override
  String get opGreaterOrEqual => 'est au moins';

  @override
  String get opBetween => 'est entre';

  @override
  String get opContains => 'contient';

  @override
  String get opStartsWith => 'commence par';

  @override
  String get opEndsWith => 'se termine par';

  @override
  String get opIsEmpty => 'est vide';

  @override
  String get opIsNotEmpty => 'n’est pas vide';

  @override
  String get opIsOneOf => 'est parmi';

  @override
  String get opIsTrue => 'est vrai';

  @override
  String get opIsFalse => 'est faux';

  @override
  String get customFilter => 'Filtre personnalisé';

  @override
  String get expression => 'Expression';

  @override
  String get selectValues => 'Sélectionner des valeurs…';

  @override
  String selectedCount(int count) => '$count sélectionné(s)';

  @override
  String get clear => 'Effacer';

  @override
  String get apply => 'Appliquer';

  @override
  String get column => 'Colonne';

  @override
  String get value => 'Valeur';

  @override
  String exprTypeName(ExprType type) => switch (type) {
    ExprType.number => 'nombre',
    ExprType.text => 'texte',
    ExprType.boolean => 'booléen',
    ExprType.date => 'date',
  };

  @override
  String expressionErrorText(ExpressionErrorKind kind, List<String> a) =>
      switch (kind) {
        ExpressionErrorKind.unexpectedCharacter =>
          'caractère inattendu « ${a[0]} »',
        ExpressionErrorKind.unterminatedText => 'texte non terminé',
        ExpressionErrorKind.unterminatedName =>
          '« ] » manquant après le nom de colonne',
        ExpressionErrorKind.unterminatedDate => '« # » manquant après la date',
        ExpressionErrorKind.invalidNumber => 'nombre invalide « ${a[0]} »',
        ExpressionErrorKind.invalidDate => 'date invalide « ${a[0]} »',
        ExpressionErrorKind.unexpectedToken => '« ${a[0]} » inattendu',
        ExpressionErrorKind.unexpectedEnd => 'fin inattendue de l’expression',
        ExpressionErrorKind.unknownColumn => 'colonne inconnue « ${a[0]} »',
        ExpressionErrorKind.unknownFunction => 'fonction inconnue « ${a[0]} »',
        ExpressionErrorKind.argumentCount =>
          '${a[0]} attend ${a[1]} argument(s), ${a[2]} fourni(s)',
        ExpressionErrorKind.argumentType =>
          'l’argument ${a[1]} de ${a[0]} doit être ${a[2]}, pas ${a[3]}',
        ExpressionErrorKind.operandType =>
          'l’opérande de ${a[0]} doit être ${a[1]}, pas ${a[2]}',
        ExpressionErrorKind.incompatibleTypes =>
          'impossible d’appliquer ${a[0]} à ${a[1]} et ${a[2]}',
        ExpressionErrorKind.unknownType => 'impossible de déterminer le type',
        ExpressionErrorKind.notAllowedHere =>
          '« ${a[0]} » n’est pas autorisé ici',
        ExpressionErrorKind.resultType =>
          'l’expression doit être ${a[0]}, pas ${a[1]}',
      };
}
