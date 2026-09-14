import '../cube/layout_aggregate.dart';
import '../expr/expr_type.dart';
import '../expr/expression_error.dart';
import '../facts/dimension.dart';
import 'tessera_strings.dart';

/// es texts. Native review welcome.
final class TesseraStringsEs extends TesseraStrings {
  const TesseraStringsEs();

  @override
  String get languageCode => 'es';

  @override
  String sumOf(String t) => 'suma de $t';

  @override
  String averageOf(String t) => 'promedio de $t';

  @override
  String minimumOf(String t) => 'mínimo de $t';

  @override
  String maximumOf(String t) => 'máximo de $t';

  @override
  String stdDevOf(String t) => 'desviación estándar de $t';

  @override
  String stdDevPopulationOf(String t) =>
      'desviación estándar poblacional de $t';

  @override
  String varianceOf(String t) => 'varianza de $t';

  @override
  String variancePopulationOf(String t) => 'varianza poblacional de $t';

  @override
  String countOf(String t) => 'recuento de $t';

  @override
  String distinctCountOf(String t) => 'valores distintos de $t';

  @override
  String get countLabel => 'recuento';

  @override
  String percentOfTotal(String base, TotalOf of) => switch (of) {
    TotalOf.row => '$base % del total de fila',
    TotalOf.column => '$base % del total de columna',
    TotalOf.grand => '$base % del total general',
    TotalOf.parentRow => '$base % de la fila principal',
    TotalOf.parentColumn => '$base % de la columna principal',
  };

  @override
  String differenceFrom(String base, String item, {required bool percent}) =>
      percent
      ? '$base % de diferencia respecto a $item'
      : '$base diferencia respecto a $item';

  @override
  String get previousItem => 'anterior';

  @override
  String get nextItem => 'siguiente';

  @override
  String runningTotalOf(String base) => '$base total acumulado';

  @override
  String rankOf(String base) => '$base posición';

  @override
  String get countOfFacts => 'Recuento de filas';

  @override
  String get sum => 'Suma';

  @override
  String get average => 'Promedio';

  @override
  String get minimum => 'Mínimo';

  @override
  String get maximum => 'Máximo';

  @override
  String get standardDeviation => 'Desviación estándar';

  @override
  String get populationStandardDeviation => 'Desviación estándar poblacional';

  @override
  String get variance => 'Varianza';

  @override
  String get populationVariance => 'Varianza poblacional';

  @override
  String get countOfValues => 'Recuento de valores';

  @override
  String get distinctCount => 'Recuento de valores distintos';

  @override
  String datePartName(DatePart part) => switch (part) {
    DatePart.year => 'año',
    DatePart.quarter => 'trimestre',
    DatePart.month => 'mes',
    DatePart.week => 'semana',
    DatePart.day => 'día',
    DatePart.weekday => 'día de la semana',
    DatePart.hour => 'hora',
  };

  @override
  String datePartLabel(String column, DatePart part) {
    final p = datePartName(part);
    return '$column $p';
  }

  static const _months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  static const _weekdays = [
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
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
  String get rows => 'Filas';

  @override
  String get columns => 'Columnas';

  @override
  String get values => 'Valores';

  @override
  String get emptyGroup => '(vacío)';

  @override
  String get total => 'Total';

  @override
  String get dropDimensionsHere => 'Suelte las dimensiones aquí';

  @override
  String get addDimension => 'Añadir dimensión';

  @override
  String get addAggregate => 'Añadir agregado';

  @override
  String get search => 'Buscar';

  @override
  String get alreadyInUse => 'ya en uso';

  @override
  String get function => 'Función';

  @override
  String get expand => 'Expandir';

  @override
  String get largeExpansionTitle => 'Expansión grande';

  @override
  String get sortAscending => 'Ordenar ascendente';

  @override
  String get sortDescending => 'Ordenar descendente';

  @override
  String get inheritSort => 'Mismo orden que el nivel superior';

  @override
  String get totalsAtEnd => 'Totales al final';

  @override
  String get totalsAtStart => 'Totales al principio';

  @override
  String get totalsHidden => 'Ocultar totales';

  @override
  String get subtotalsAbove => 'Subtotales encima del grupo';

  @override
  String get subtotalsBelow => 'Subtotales debajo del grupo';

  @override
  String get subtotalsLeft => 'Subtotales a la izquierda del grupo';

  @override
  String get subtotalsRight => 'Subtotales a la derecha del grupo';

  @override
  String get subtotalsHidden => 'Ocultar subtotales';

  @override
  String get expandAll => 'Expandir todo';

  @override
  String get collapseAll => 'Contraer todo';

  @override
  String largeExpansion(String label, int added, {required bool isRow}) =>
      'Expandir «$label» añade $added ${isRow ? 'filas' : 'columnas'}. ¿Continuar?';

  @override
  String get filter => 'Filtro';

  @override
  String get noFilter => 'Sin filtro';

  @override
  String get addCondition => 'Añadir condición';

  @override
  String get addGroup => 'Añadir grupo';

  @override
  String get addExpression => 'Añadir expresión';

  @override
  String get matchAll => 'Todas las condiciones';

  @override
  String get matchAny => 'Cualquiera de las condiciones';

  @override
  String get negate => 'No';

  @override
  String get opEquals => 'es igual a';

  @override
  String get opNotEquals => 'es distinto de';

  @override
  String get opLess => 'es menor que';

  @override
  String get opLessOrEqual => 'es como máximo';

  @override
  String get opGreater => 'es mayor que';

  @override
  String get opGreaterOrEqual => 'es como mínimo';

  @override
  String get opBetween => 'está entre';

  @override
  String get opContains => 'contiene';

  @override
  String get opStartsWith => 'empieza por';

  @override
  String get opEndsWith => 'termina en';

  @override
  String get opIsEmpty => 'está vacío';

  @override
  String get opIsNotEmpty => 'no está vacío';

  @override
  String get opIsOneOf => 'es uno de';

  @override
  String get opIsTrue => 'es verdadero';

  @override
  String get opIsFalse => 'es falso';

  @override
  String get customFilter => 'Filtro personalizado';

  @override
  String get expression => 'Expresión';

  @override
  String get selectValues => 'Seleccionar valores…';

  @override
  String selectedCount(int count) => '$count seleccionados';

  @override
  String get clear => 'Borrar';

  @override
  String get apply => 'Aplicar';

  @override
  String get column => 'Columna';

  @override
  String get value => 'Valor';

  @override
  String exprTypeName(ExprType type) => switch (type) {
    ExprType.number => 'número',
    ExprType.text => 'texto',
    ExprType.boolean => 'booleano',
    ExprType.date => 'fecha',
  };

  @override
  String expressionErrorText(
    ExpressionErrorKind kind,
    List<String> a,
  ) => switch (kind) {
    ExpressionErrorKind.unexpectedCharacter => 'carácter inesperado "${a[0]}"',
    ExpressionErrorKind.unterminatedText => 'texto sin cerrar',
    ExpressionErrorKind.unterminatedName =>
      'falta "]" tras el nombre de columna',
    ExpressionErrorKind.unterminatedDate => 'falta "#" tras la fecha',
    ExpressionErrorKind.invalidNumber => 'número no válido "${a[0]}"',
    ExpressionErrorKind.invalidDate => 'fecha no válida "${a[0]}"',
    ExpressionErrorKind.unexpectedToken => '"${a[0]}" inesperado',
    ExpressionErrorKind.unexpectedEnd => 'fin inesperado de la expresión',
    ExpressionErrorKind.unknownColumn => 'columna desconocida "${a[0]}"',
    ExpressionErrorKind.unknownFunction => 'función desconocida "${a[0]}"',
    ExpressionErrorKind.argumentCount =>
      '${a[0]} espera ${a[1]} argumento(s), se dieron ${a[2]}',
    ExpressionErrorKind.argumentType =>
      'el argumento ${a[1]} de ${a[0]} debe ser ${a[2]}, no ${a[3]}',
    ExpressionErrorKind.operandType =>
      'el operando de ${a[0]} debe ser ${a[1]}, no ${a[2]}',
    ExpressionErrorKind.incompatibleTypes =>
      'no se puede aplicar ${a[0]} a ${a[1]} y ${a[2]}',
    ExpressionErrorKind.unknownType => 'no se puede determinar el tipo',
    ExpressionErrorKind.notAllowedHere => '"${a[0]}" no está permitido aquí',
    ExpressionErrorKind.resultType =>
      'la expresión debe ser ${a[0]}, no ${a[1]}',
  };
}
