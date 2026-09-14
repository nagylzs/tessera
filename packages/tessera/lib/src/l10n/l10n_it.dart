import '../cube/layout_aggregate.dart';
import '../expr/expr_type.dart';
import '../expr/expression_error.dart';
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
  String percentOfTotal(String base, TotalOf of) => switch (of) {
    TotalOf.row => '$base % del totale riga',
    TotalOf.column => '$base % del totale colonna',
    TotalOf.grand => '$base % del totale generale',
    TotalOf.parentRow => '$base % della riga padre',
    TotalOf.parentColumn => '$base % della colonna padre',
  };

  @override
  String differenceFrom(String base, String item, {required bool percent}) =>
      percent ? '$base % differenza da $item' : '$base differenza da $item';

  @override
  String get previousItem => 'precedente';

  @override
  String get nextItem => 'successivo';

  @override
  String runningTotalOf(String base) => '$base totale progressivo';

  @override
  String rankOf(String base) => '$base posizione';

  @override
  String get showValuesAs => 'Mostra valori come';

  @override
  String valueDisplayName(ValueDisplay display) => switch (display) {
    ValueDisplay.plain => 'Valore semplice',
    ValueDisplay.percentOfRow => '% del totale riga',
    ValueDisplay.percentOfColumn => '% del totale colonna',
    ValueDisplay.percentOfGrand => '% del totale generale',
    ValueDisplay.percentOfParentRow => '% della riga padre',
    ValueDisplay.percentOfParentColumn => '% della colonna padre',
    ValueDisplay.differenceFromPreviousRow =>
      'Differenza dalla riga precedente',
    ValueDisplay.differenceFromPreviousColumn =>
      'Differenza dalla colonna precedente',
    ValueDisplay.percentDifferenceFromPreviousRow =>
      '% differenza dalla riga precedente',
    ValueDisplay.percentDifferenceFromPreviousColumn =>
      '% differenza dalla colonna precedente',
    ValueDisplay.runningTotalRows => 'Totale progressivo per righe',
    ValueDisplay.runningTotalColumns => 'Totale progressivo per colonne',
    ValueDisplay.rankRows => 'Posizione tra le righe',
    ValueDisplay.rankColumns => 'Posizione tra le colonne',
  };

  @override
  String get formula => 'Formula';

  @override
  String get labelField => 'Etichetta';

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

  @override
  String get filter => 'Filtro';

  @override
  String get noFilter => 'Nessun filtro';

  @override
  String get addCondition => 'Aggiungi condizione';

  @override
  String get addGroup => 'Aggiungi gruppo';

  @override
  String get addExpression => 'Aggiungi espressione';

  @override
  String get matchAll => 'Tutte le condizioni';

  @override
  String get matchAny => 'Almeno una condizione';

  @override
  String get negate => 'Non';

  @override
  String get opEquals => 'è uguale a';

  @override
  String get opNotEquals => 'è diverso da';

  @override
  String get opLess => 'è minore di';

  @override
  String get opLessOrEqual => 'è al massimo';

  @override
  String get opGreater => 'è maggiore di';

  @override
  String get opGreaterOrEqual => 'è almeno';

  @override
  String get opBetween => 'è compreso tra';

  @override
  String get opContains => 'contiene';

  @override
  String get opStartsWith => 'inizia con';

  @override
  String get opEndsWith => 'finisce con';

  @override
  String get opIsEmpty => 'è vuoto';

  @override
  String get opIsNotEmpty => 'non è vuoto';

  @override
  String get opIsOneOf => 'è uno di';

  @override
  String get opIsTrue => 'è vero';

  @override
  String get opIsFalse => 'è falso';

  @override
  String get customFilter => 'Filtro personalizzato';

  @override
  String get expression => 'Espressione';

  @override
  String get selectValues => 'Seleziona valori…';

  @override
  String selectedCount(int count) => '$count selezionati';

  @override
  String get clear => 'Cancella';

  @override
  String get apply => 'Applica';

  @override
  String get column => 'Colonna';

  @override
  String get value => 'Valore';

  @override
  String exprTypeName(ExprType type) => switch (type) {
    ExprType.number => 'numero',
    ExprType.text => 'testo',
    ExprType.boolean => 'booleano',
    ExprType.date => 'data',
  };

  @override
  String expressionErrorText(ExpressionErrorKind kind, List<String> a) =>
      switch (kind) {
        ExpressionErrorKind.unexpectedCharacter =>
          'carattere inatteso "${a[0]}"',
        ExpressionErrorKind.unterminatedText => 'testo non terminato',
        ExpressionErrorKind.unterminatedName =>
          'manca "]" dopo il nome della colonna',
        ExpressionErrorKind.unterminatedDate => 'manca "#" dopo la data',
        ExpressionErrorKind.invalidNumber => 'numero non valido "${a[0]}"',
        ExpressionErrorKind.invalidDate => 'data non valida "${a[0]}"',
        ExpressionErrorKind.unexpectedToken => '"${a[0]}" inatteso',
        ExpressionErrorKind.unexpectedEnd => 'fine inattesa dell’espressione',
        ExpressionErrorKind.unknownColumn => 'colonna sconosciuta "${a[0]}"',
        ExpressionErrorKind.unknownFunction => 'funzione sconosciuta "${a[0]}"',
        ExpressionErrorKind.argumentCount =>
          '${a[0]} richiede ${a[1]} argomento/i, forniti ${a[2]}',
        ExpressionErrorKind.argumentType =>
          'l’argomento ${a[1]} di ${a[0]} deve essere ${a[2]}, non ${a[3]}',
        ExpressionErrorKind.operandType =>
          'l’operando di ${a[0]} deve essere ${a[1]}, non ${a[2]}',
        ExpressionErrorKind.incompatibleTypes =>
          'impossibile applicare ${a[0]} a ${a[1]} e ${a[2]}',
        ExpressionErrorKind.unknownType => 'impossibile determinare il tipo',
        ExpressionErrorKind.notAllowedHere => '"${a[0]}" non è consentito qui',
        ExpressionErrorKind.resultType =>
          'l’espressione deve essere ${a[0]}, non ${a[1]}',
      };
}
