import '../cube/layout_aggregate.dart';
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
}
