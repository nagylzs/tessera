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
  String countOf(String t) => 'nombre de $t';

  @override
  String distinctCountOf(String t) => 'valeurs distinctes de $t';

  @override
  String get countLabel => 'nombre';

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
  String get expandAll => 'Tout développer';

  @override
  String get collapseAll => 'Tout réduire';

  @override
  String largeExpansion(String label, int added, {required bool isRow}) =>
      'Développer « $label » ajoute $added ${isRow ? 'lignes' : 'colonnes'}. Continuer ?';
}
