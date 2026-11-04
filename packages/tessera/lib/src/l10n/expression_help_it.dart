import 'expression_help.dart';

/// it texts of the expression help. Native review welcome.
final class ExpressionHelpStringsIt extends ExpressionHelpStrings {
  const ExpressionHelpStringsIt();

  @override
  String get languageCode => 'it';

  @override
  String get title => 'Guida alle espressioni';

  @override
  String get tapToInsert =>
      'Tocca un esempio, una colonna o una funzione per inserirlo.';

  @override
  String intro(ExpressionHelpUse use) => switch (use) {
    ExpressionHelpUse.filter =>
      'Un filtro mantiene le righe per cui l’espressione è vera. '
          'Combina le condizioni con and, or e not.',
    ExpressionHelpUse.measure =>
      'Una misura calcolata viene valutata per ogni riga a partire dalle sue '
          'colonne, poi se ne calcola la somma o la media come per una '
          'colonna.',
    ExpressionHelpUse.dimension =>
      'Una dimensione calcolata raggruppa le righe in base al valore '
          'dell’espressione, come farebbe una colonna: un numero, un testo, '
          'una data o true/false.',
    ExpressionHelpUse.formula =>
      'Una formula di cella viene calcolata in ogni cella della tabella pivot '
          'a partire dagli aggregati della cella, come sum(x) o count.',
  };

  @override
  String get examples => 'Esempi';

  @override
  String get columns => 'Colonne';

  @override
  String get aggregates => 'Aggregati';

  @override
  String get operators => 'Operatori';

  @override
  String get values => 'Valori';

  @override
  String get rules => 'Regole';

  @override
  String get functions => 'Funzioni';

  @override
  String get aggregateArgument =>
      'x è una colonna o un calcolo sulle colonne di una riga: '
      'sum(quantity * price). count da solo conta le righe.';

  @override
  String groupName(ExpressionHelpGroup group) => switch (group) {
    ExpressionHelpGroup.conditional => 'Condizioni',
    ExpressionHelpGroup.numbers => 'Numeri',
    ExpressionHelpGroup.text => 'Testo',
    ExpressionHelpGroup.dates => 'Date',
    ExpressionHelpGroup.other => 'Altre funzioni',
  };

  @override
  String operatorText(ExpressionHelpOperator operator) => switch (operator) {
    ExpressionHelpOperator.arithmetic =>
      'Addizione, sottrazione, moltiplicazione, divisione. Dividere per zero '
          'dà un valore vuoto.',
    ExpressionHelpOperator.remainder => 'Il resto di una divisione: 7 % 3 è 1.',
    ExpressionHelpOperator.comparison =>
      'Uguale, diverso, minore, minore o uguale, maggiore, maggiore o '
          'uguale. Funzionano anche == e !=.',
    ExpressionHelpOperator.logic =>
      'Entrambe le condizioni, almeno una delle due, il contrario.',
    ExpressionHelpOperator.inList =>
      'x è uno dei valori elencati, o nessuno di essi.',
    ExpressionHelpOperator.between => 'a ≤ x ≤ b, estremi inclusi.',
    ExpressionHelpOperator.emptyTest => 'x non ha un valore, o ne ha uno.',
    ExpressionHelpOperator.dates =>
      'n giorni dopo o prima di una data; i giorni tra due date.',
  };

  @override
  String literalText(ExpressionHelpLiteral literal) => switch (literal) {
    ExpressionHelpLiteral.number =>
      'Numeri, sempre con il punto decimale: 12.5, non 12,5.',
    ExpressionHelpLiteral.text =>
      'Testo tra virgolette doppie o singole. Una virgoletta all’interno va '
          'raddoppiata: "say ""hi""".',
    ExpressionHelpLiteral.date =>
      'Date, con l’ora se serve, tra due simboli #, prima l’anno.',
    ExpressionHelpLiteral.boolean => 'Valori logici.',
    ExpressionHelpLiteral.empty => 'Il valore vuoto.',
    ExpressionHelpLiteral.name =>
      'Un nome di colonna con spazi o punteggiatura, o scritto come una '
          'parola chiave, va tra parentesi quadre.',
  };

  @override
  String ruleText(ExpressionHelpRule rule) => switch (rule) {
    ExpressionHelpRule.emptyValues =>
      'Un calcolo o un confronto con un valore vuoto è vuoto: '
          'price * 2 e price > 0 sono vuoti dove lo è il prezzo. '
          'coalesce(price, 0) usa 0 al suo posto; price is empty trova le '
          'righe senza prezzo.',
    ExpressionHelpRule.filters =>
      'Un filtro mantiene una riga solo dove la sua espressione è vera: '
          'discount > 0 scarta le righe senza sconto, '
          'discount > 0 or discount is empty le mantiene.',
    ExpressionHelpRule.letterCase =>
      'Nei nomi delle funzioni e nelle parole chiave maiuscole e minuscole '
          'sono indifferenti (YEAR, Year); i nomi delle colonne devono '
          'corrispondere esattamente. I confronti tra testi distinguono '
          'maiuscole e minuscole: confronta lower(x) per ignorarle.',
  };

  @override
  ({String signature, String description}) function(
    ExpressionHelpFunction function,
  ) => switch (function) {
    ExpressionHelpFunction.ifElse => (
      signature: 'if(condizione, a, b)',
      description:
          'Dove la condizione è vera, a; altrimenti b (anche dove la '
          'condizione è vuota). a e b sono dello stesso tipo.',
    ),
    ExpressionHelpFunction.coalesce => (
      signature: 'coalesce(a, b, …)',
      description: 'Il primo dei suoi argomenti che non è vuoto.',
    ),
    ExpressionHelpFunction.isempty => (
      signature: 'isempty(x)',
      description: 'Vero dove x è vuoto, come x is empty.',
    ),
    ExpressionHelpFunction.abs => (
      signature: 'abs(x)',
      description: 'x senza il segno.',
    ),
    ExpressionHelpFunction.round => (
      signature: 'round(x, decimali)',
      description:
          'x arrotondato a tante cifre decimali quante ne indica decimali; '
          'senza decimali, a un numero intero. Se decimali è negativo, '
          'arrotonda a decine, centinaia…: round(1234.5, -2) è 1200.',
    ),
    ExpressionHelpFunction.floor => (
      signature: 'floor(x)',
      description:
          'x arrotondato per difetto a un numero intero: floor(2.7) è 2, '
          'floor(-2.5) è -3.',
    ),
    ExpressionHelpFunction.ceil => (
      signature: 'ceil(x)',
      description:
          'x arrotondato per eccesso a un numero intero: ceil(2.1) è 3.',
    ),
    ExpressionHelpFunction.sqrt => (
      signature: 'sqrt(x)',
      description: 'La radice quadrata di x; vuoto per un x negativo.',
    ),
    ExpressionHelpFunction.min => (
      signature: 'min(x, y, …)',
      description: 'Il più piccolo dei numeri, tralasciando quelli vuoti.',
    ),
    ExpressionHelpFunction.max => (
      signature: 'max(x, y, …)',
      description: 'Il più grande dei numeri, tralasciando quelli vuoti.',
    ),
    ExpressionHelpFunction.number => (
      signature: 'number(testo)',
      description:
          'Il numero scritto in un testo, con il punto decimale; vuoto se il '
          'testo non è un numero.',
    ),
    ExpressionHelpFunction.len => (
      signature: 'len(testo)',
      description: 'Il numero di caratteri del testo.',
    ),
    ExpressionHelpFunction.lower => (
      signature: 'lower(testo)',
      description: 'Il testo in minuscolo.',
    ),
    ExpressionHelpFunction.upper => (
      signature: 'upper(testo)',
      description: 'Il testo in maiuscolo.',
    ),
    ExpressionHelpFunction.trim => (
      signature: 'trim(testo)',
      description: 'Il testo senza spazi all’inizio e alla fine.',
    ),
    ExpressionHelpFunction.left => (
      signature: 'left(testo, n)',
      description: 'I primi n caratteri del testo.',
    ),
    ExpressionHelpFunction.right => (
      signature: 'right(testo, n)',
      description: 'Gli ultimi n caratteri del testo.',
    ),
    ExpressionHelpFunction.substring => (
      signature: 'substring(testo, inizio, lunghezza)',
      description:
          'lunghezza caratteri del testo dalla posizione inizio, dove il '
          'primo carattere è 1; senza lunghezza, il resto del testo.',
    ),
    ExpressionHelpFunction.contains => (
      signature: 'contains(testo, parte)',
      description: 'Vero dove parte compare nel testo.',
    ),
    ExpressionHelpFunction.startswith => (
      signature: 'startswith(testo, parte)',
      description: 'Vero dove il testo inizia con parte.',
    ),
    ExpressionHelpFunction.endswith => (
      signature: 'endswith(testo, parte)',
      description: 'Vero dove il testo finisce con parte.',
    ),
    ExpressionHelpFunction.replace => (
      signature: 'replace(testo, vecchio, nuovo)',
      description: 'Il testo con ogni vecchio sostituito da nuovo.',
    ),
    ExpressionHelpFunction.concat => (
      signature: 'concat(a, b, …)',
      description:
          'I testi uniti, tralasciando quelli vuoti. text(x) trasforma un '
          'numero o una data in testo.',
    ),
    ExpressionHelpFunction.text => (
      signature: 'text(x)',
      description:
          'Un numero, una data o true/false come testo: text(1.5) è "1.5", '
          'text(#2024-01-31#) è "2024-01-31".',
    ),
    ExpressionHelpFunction.year => (
      signature: 'year(data)',
      description: 'L’anno della data.',
    ),
    ExpressionHelpFunction.quarter => (
      signature: 'quarter(data)',
      description: 'Il trimestre dell’anno, da 1 a 4.',
    ),
    ExpressionHelpFunction.month => (
      signature: 'month(data)',
      description: 'Il mese, da 1 a 12.',
    ),
    ExpressionHelpFunction.week => (
      signature: 'week(data)',
      description: 'Il numero di settimana ISO, da 1 a 53.',
    ),
    ExpressionHelpFunction.day => (
      signature: 'day(data)',
      description: 'Il giorno del mese, da 1 a 31.',
    ),
    ExpressionHelpFunction.weekday => (
      signature: 'weekday(data)',
      description: 'Il giorno della settimana, da 1 (lunedì) a 7 (domenica).',
    ),
    ExpressionHelpFunction.hour => (
      signature: 'hour(data)',
      description: 'L’ora, da 0 a 23.',
    ),
    ExpressionHelpFunction.dateOfText => (
      signature: 'date(testo)',
      description:
          'La data scritta in un testo, prima l’anno: date("2024-01-31"); '
          'vuoto se il testo non è una data.',
    ),
    ExpressionHelpFunction.dateOfParts => (
      signature: 'date(anno, mese, giorno)',
      description: 'La data dell’anno, del mese e del giorno indicati.',
    ),
    ExpressionHelpFunction.today => (
      signature: 'today()',
      description: 'La data di oggi.',
    ),
  };
}
