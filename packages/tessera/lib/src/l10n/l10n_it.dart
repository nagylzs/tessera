import '../facts/dimension.dart';
import 'tessera_strings.dart';

/// it texts. Native review welcome.
final class TesseraStringsIt extends TesseraStrings {
  const TesseraStringsIt();

  @override
  String get languageCode => 'it';

  @override
  String sumOf(String t) => 'somma di $t';

  @override
  String averageOf(String t) => 'media di $t';

  @override
  String minimumOf(String t) => 'minimo di $t';

  @override
  String maximumOf(String t) => 'massimo di $t';

  @override
  String stdDevOf(String t) => 'deviazione standard di $t';

  @override
  String stdDevPopulationOf(String t) =>
      'deviazione standard (popolazione) di $t';

  @override
  String varianceOf(String t) => 'varianza di $t';

  @override
  String variancePopulationOf(String t) => 'varianza (popolazione) di $t';

  @override
  String countOf(String t) => 'conteggio di $t';

  @override
  String distinctCountOf(String t) => 'valori distinti di $t';

  @override
  String get countLabel => 'conteggio';

  @override
  String get countOfFacts => 'Conteggio righe';

  @override
  String get sum => 'Somma';

  @override
  String get average => 'Media';

  @override
  String get minimum => 'Minimo';

  @override
  String get maximum => 'Massimo';

  @override
  String get standardDeviation => 'Deviazione standard';

  @override
  String get populationStandardDeviation => 'Deviazione standard (popolazione)';

  @override
  String get variance => 'Varianza';

  @override
  String get populationVariance => 'Varianza (popolazione)';

  @override
  String get countOfValues => 'Conteggio valori';

  @override
  String get distinctCount => 'Conteggio valori distinti';

  @override
  String datePartName(DatePart part) => switch (part) {
    DatePart.year => 'anno',
    DatePart.quarter => 'trimestre',
    DatePart.month => 'mese',
    DatePart.week => 'settimana',
    DatePart.day => 'giorno',
    DatePart.weekday => 'giorno della settimana',
    DatePart.hour => 'ora',
  };

  @override
  String datePartLabel(String column, DatePart part) {
    final p = datePartName(part);
    return '$column $p';
  }

  static const _months = [
    'gennaio',
    'febbraio',
    'marzo',
    'aprile',
    'maggio',
    'giugno',
    'luglio',
    'agosto',
    'settembre',
    'ottobre',
    'novembre',
    'dicembre',
  ];

  static const _weekdays = [
    'lunedì',
    'martedì',
    'mercoledì',
    'giovedì',
    'venerdì',
    'sabato',
    'domenica',
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
  String get groupSeparator => '.';

  @override
  String get rows => 'Righe';

  @override
  String get columns => 'Colonne';

  @override
  String get values => 'Valori';

  @override
  String get emptyGroup => '(vuoto)';

  @override
  String get total => 'Totale';

  @override
  String get dropDimensionsHere => 'Trascina qui le dimensioni';

  @override
  String get addDimension => 'Aggiungi dimensione';

  @override
  String get addAggregate => 'Aggiungi aggregato';

  @override
  String get search => 'Cerca';

  @override
  String get alreadyInUse => 'già in uso';

  @override
  String get function => 'Funzione';

  @override
  String get expand => 'Espandi';

  @override
  String get largeExpansionTitle => 'Espansione ampia';

  @override
  String get sortAscending => 'Ordina crescente';

  @override
  String get sortDescending => 'Ordina decrescente';

  @override
  String get inheritSort => 'Stesso ordine del livello superiore';

  @override
  String get totalsAtEnd => 'Totali alla fine';

  @override
  String get totalsAtStart => 'Totali all\'inizio';

  @override
  String get totalsHidden => 'Nascondi i totali';

  @override
  String get subtotalsAbove => 'Subtotali sopra il gruppo';

  @override
  String get subtotalsBelow => 'Subtotali sotto il gruppo';

  @override
  String get subtotalsLeft => 'Subtotali a sinistra del gruppo';

  @override
  String get subtotalsRight => 'Subtotali a destra del gruppo';

  @override
  String get subtotalsHidden => 'Nascondi i subtotali';

  @override
  String get expandAll => 'Espandi tutto';

  @override
  String get collapseAll => 'Comprimi tutto';

  @override
  String largeExpansion(String label, int added, {required bool isRow}) =>
      'Espandere "$label" aggiunge $added ${isRow ? 'righe' : 'colonne'}. Continuare?';
}
