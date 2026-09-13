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
  String countOf(String t) => 'recuento de $t';

  @override
  String distinctCountOf(String t) => 'valores distintos de $t';

  @override
  String get countLabel => 'recuento';

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
  String get expandAll => 'Expandir todo';

  @override
  String get collapseAll => 'Contraer todo';

  @override
  String largeExpansion(String label, int added, {required bool isRow}) =>
      'Expandir «$label» añade $added ${isRow ? 'filas' : 'columnas'}. ¿Continuar?';
}
