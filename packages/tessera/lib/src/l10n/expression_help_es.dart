import 'expression_help.dart';

/// es texts of the expression help. Native review welcome.
final class ExpressionHelpStringsEs extends ExpressionHelpStrings {
  const ExpressionHelpStringsEs();

  @override
  String get languageCode => 'es';

  @override
  String get title => 'Ayuda sobre expresiones';

  @override
  String get tapToInsert =>
      'Toque un ejemplo, una columna o una función para insertarlo.';

  @override
  String intro(ExpressionHelpUse use) => switch (use) {
    ExpressionHelpUse.filter =>
      'Un filtro conserva las filas para las que la expresión es verdadera. '
          'Combine las condiciones con and, or y not.',
    ExpressionHelpUse.measure =>
      'Una medida calculada se evalúa en cada fila a partir de sus columnas '
          'y después se suma o se promedia como una columna.',
    ExpressionHelpUse.dimension =>
      'Una dimensión calculada agrupa las filas por el valor de la '
          'expresión, como lo haría una columna: un número, un texto, una '
          'fecha o true/false.',
    ExpressionHelpUse.formula =>
      'Una fórmula de celda se calcula en cada celda de la tabla dinámica a '
          'partir de los agregados de la celda, como sum(x) o count.',
  };

  @override
  String get examples => 'Ejemplos';

  @override
  String get columns => 'Columnas';

  @override
  String get aggregates => 'Agregados';

  @override
  String get operators => 'Operadores';

  @override
  String get values => 'Valores';

  @override
  String get rules => 'Reglas';

  @override
  String get functions => 'Funciones';

  @override
  String get aggregateArgument =>
      'x es una columna o un cálculo sobre las columnas de una fila: '
      'sum(quantity * price). count sin argumento cuenta las filas.';

  @override
  String groupName(ExpressionHelpGroup group) => switch (group) {
    ExpressionHelpGroup.conditional => 'Condiciones',
    ExpressionHelpGroup.numbers => 'Números',
    ExpressionHelpGroup.text => 'Texto',
    ExpressionHelpGroup.dates => 'Fechas',
    ExpressionHelpGroup.other => 'Otras funciones',
  };

  @override
  String operatorText(ExpressionHelpOperator operator) => switch (operator) {
    ExpressionHelpOperator.arithmetic =>
      'Suma, resta, multiplicación, división. Dividir por cero da un valor '
          'vacío.',
    ExpressionHelpOperator.remainder => 'El resto de una división: 7 % 3 es 1.',
    ExpressionHelpOperator.comparison =>
      'Igual, distinto, menor, menor o igual, mayor, mayor o igual. '
          '== y != también funcionan.',
    ExpressionHelpOperator.logic =>
      'Ambas condiciones, cualquiera de ellas, lo contrario.',
    ExpressionHelpOperator.inList =>
      'x es uno de los valores indicados, o ninguno de ellos.',
    ExpressionHelpOperator.between => 'a ≤ x ≤ b, ambos extremos incluidos.',
    ExpressionHelpOperator.emptyTest => 'x no tiene valor, o lo tiene.',
    ExpressionHelpOperator.dates =>
      'n días después o antes de una fecha; los días entre dos fechas.',
  };

  @override
  String literalText(ExpressionHelpLiteral literal) => switch (literal) {
    ExpressionHelpLiteral.number =>
      'Números, siempre con punto decimal: 12.5, no 12,5.',
    ExpressionHelpLiteral.text =>
      'Texto entre comillas dobles o simples. Una comilla dentro se '
          'duplica: "say ""hi""".',
    ExpressionHelpLiteral.date =>
      'Fechas, con hora si hace falta, entre dos signos #, primero el año.',
    ExpressionHelpLiteral.boolean => 'Valores lógicos.',
    ExpressionHelpLiteral.empty => 'El valor vacío.',
    ExpressionHelpLiteral.name =>
      'Un nombre de columna con espacios o signos de puntuación, o que se '
          'escribe como una palabra clave, va entre corchetes.',
  };

  @override
  String ruleText(ExpressionHelpRule rule) => switch (rule) {
    ExpressionHelpRule.emptyValues =>
      'Un cálculo o una comparación con un valor vacío da un valor vacío: '
          'price * 2 y price > 0 están vacíos donde el precio lo está. '
          'coalesce(price, 0) usa 0 en su lugar; price is empty encuentra '
          'las filas sin precio.',
    ExpressionHelpRule.filters =>
      'Un filtro conserva una fila solo donde su expresión es verdadera: '
          'discount > 0 descarta las filas sin descuento, '
          'discount > 0 or discount is empty las conserva.',
    ExpressionHelpRule.letterCase =>
      'Los nombres de funciones y las palabras clave no distinguen '
          'mayúsculas de minúsculas (YEAR, Year); los nombres de columna '
          'deben coincidir exactamente. Las comparaciones de texto sí las '
          'distinguen: compare lower(x) para ignorarlas.',
  };

  @override
  ({String signature, String description}) function(
    ExpressionHelpFunction function,
  ) => switch (function) {
    ExpressionHelpFunction.ifElse => (
      signature: 'if(condición, a, b)',
      description:
          'Donde la condición es verdadera, a; si no, b (también donde la '
          'condición está vacía). a y b son del mismo tipo.',
    ),
    ExpressionHelpFunction.coalesce => (
      signature: 'coalesce(a, b, …)',
      description: 'El primero de sus argumentos que no está vacío.',
    ),
    ExpressionHelpFunction.isempty => (
      signature: 'isempty(x)',
      description: 'Verdadero donde x está vacío; equivale a x is empty.',
    ),
    ExpressionHelpFunction.abs => (
      signature: 'abs(x)',
      description: 'x sin su signo.',
    ),
    ExpressionHelpFunction.round => (
      signature: 'round(x, decimales)',
      description:
          'x redondeado a tantos decimales como indique decimales; sin '
          'decimales, a un número entero. Si decimales es negativo, redondea '
          'a decenas, centenas…: round(1234.5, -2) es 1200.',
    ),
    ExpressionHelpFunction.floor => (
      signature: 'floor(x)',
      description:
          'x redondeado hacia abajo a un número entero: floor(2.7) es 2, '
          'floor(-2.5) es -3.',
    ),
    ExpressionHelpFunction.ceil => (
      signature: 'ceil(x)',
      description:
          'x redondeado hacia arriba a un número entero: ceil(2.1) es 3.',
    ),
    ExpressionHelpFunction.sqrt => (
      signature: 'sqrt(x)',
      description: 'La raíz cuadrada de x; vacío para un x negativo.',
    ),
    ExpressionHelpFunction.min => (
      signature: 'min(x, y, …)',
      description: 'El menor de los números, omitiendo los vacíos.',
    ),
    ExpressionHelpFunction.max => (
      signature: 'max(x, y, …)',
      description: 'El mayor de los números, omitiendo los vacíos.',
    ),
    ExpressionHelpFunction.number => (
      signature: 'number(texto)',
      description:
          'El número escrito en un texto, con punto decimal; vacío si el '
          'texto no es un número.',
    ),
    ExpressionHelpFunction.len => (
      signature: 'len(texto)',
      description: 'El número de caracteres del texto.',
    ),
    ExpressionHelpFunction.lower => (
      signature: 'lower(texto)',
      description: 'El texto en minúsculas.',
    ),
    ExpressionHelpFunction.upper => (
      signature: 'upper(texto)',
      description: 'El texto en mayúsculas.',
    ),
    ExpressionHelpFunction.trim => (
      signature: 'trim(texto)',
      description: 'El texto sin espacios al principio ni al final.',
    ),
    ExpressionHelpFunction.left => (
      signature: 'left(texto, n)',
      description: 'Los primeros n caracteres del texto.',
    ),
    ExpressionHelpFunction.right => (
      signature: 'right(texto, n)',
      description: 'Los últimos n caracteres del texto.',
    ),
    ExpressionHelpFunction.substring => (
      signature: 'substring(texto, inicio, longitud)',
      description:
          'longitud caracteres del texto desde la posición inicio, siendo 1 '
          'el primer carácter; sin longitud, el resto del texto.',
    ),
    ExpressionHelpFunction.contains => (
      signature: 'contains(texto, parte)',
      description: 'Verdadero donde parte aparece en el texto.',
    ),
    ExpressionHelpFunction.startswith => (
      signature: 'startswith(texto, parte)',
      description: 'Verdadero donde el texto empieza por parte.',
    ),
    ExpressionHelpFunction.endswith => (
      signature: 'endswith(texto, parte)',
      description: 'Verdadero donde el texto termina en parte.',
    ),
    ExpressionHelpFunction.replace => (
      signature: 'replace(texto, antiguo, nuevo)',
      description: 'El texto con cada antiguo sustituido por nuevo.',
    ),
    ExpressionHelpFunction.concat => (
      signature: 'concat(a, b, …)',
      description:
          'Los textos unidos, omitiendo los vacíos. text(x) convierte un '
          'número o una fecha en texto.',
    ),
    ExpressionHelpFunction.text => (
      signature: 'text(x)',
      description:
          'Un número, una fecha o true/false como texto: text(1.5) es "1.5", '
          'text(#2024-01-31#) es "2024-01-31".',
    ),
    ExpressionHelpFunction.year => (
      signature: 'year(fecha)',
      description: 'El año de la fecha.',
    ),
    ExpressionHelpFunction.quarter => (
      signature: 'quarter(fecha)',
      description: 'El trimestre del año, de 1 a 4.',
    ),
    ExpressionHelpFunction.month => (
      signature: 'month(fecha)',
      description: 'El mes, de 1 a 12.',
    ),
    ExpressionHelpFunction.week => (
      signature: 'week(fecha)',
      description: 'El número de semana ISO, de 1 a 53.',
    ),
    ExpressionHelpFunction.day => (
      signature: 'day(fecha)',
      description: 'El día del mes, de 1 a 31.',
    ),
    ExpressionHelpFunction.weekday => (
      signature: 'weekday(fecha)',
      description: 'El día de la semana, de 1 (lunes) a 7 (domingo).',
    ),
    ExpressionHelpFunction.hour => (
      signature: 'hour(fecha)',
      description: 'La hora, de 0 a 23.',
    ),
    ExpressionHelpFunction.dateOfText => (
      signature: 'date(texto)',
      description:
          'La fecha escrita en un texto, primero el año: date("2024-01-31"); '
          'vacío si el texto no es una fecha.',
    ),
    ExpressionHelpFunction.dateOfParts => (
      signature: 'date(año, mes, día)',
      description: 'La fecha del año, el mes y el día indicados.',
    ),
    ExpressionHelpFunction.today => (
      signature: 'today()',
      description: 'La fecha de hoy.',
    ),
  };
}
