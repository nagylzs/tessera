import '../facts/dimension.dart';
import 'tessera_strings.dart';

/// pt texts. Native review welcome.
final class TesseraStringsPt extends TesseraStrings {
  const TesseraStringsPt();

  @override
  String get languageCode => 'pt';

  @override
  String sumOf(String t) => 'soma de $t';

  @override
  String averageOf(String t) => 'média de $t';

  @override
  String minimumOf(String t) => 'mínimo de $t';

  @override
  String maximumOf(String t) => 'máximo de $t';

  @override
  String countOf(String t) => 'contagem de $t';

  @override
  String distinctCountOf(String t) => 'valores distintos de $t';

  @override
  String get countLabel => 'contagem';

  @override
  String get countOfFacts => 'Contagem de linhas';

  @override
  String get sum => 'Soma';

  @override
  String get average => 'Média';

  @override
  String get minimum => 'Mínimo';

  @override
  String get maximum => 'Máximo';

  @override
  String get countOfValues => 'Contagem de valores';

  @override
  String get distinctCount => 'Contagem de valores distintos';

  @override
  String datePartName(DatePart part) => switch (part) {
    DatePart.year => 'ano',
    DatePart.quarter => 'trimestre',
    DatePart.month => 'mês',
    DatePart.week => 'semana',
    DatePart.day => 'dia',
    DatePart.weekday => 'dia da semana',
    DatePart.hour => 'hora',
  };

  @override
  String datePartLabel(String column, DatePart part) {
    final p = datePartName(part);
    return '$column $p';
  }

  static const _months = [
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];

  static const _weekdays = [
    'segunda-feira',
    'terça-feira',
    'quarta-feira',
    'quinta-feira',
    'sexta-feira',
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
  String get rows => 'Linhas';

  @override
  String get columns => 'Colunas';

  @override
  String get values => 'Valores';

  @override
  String get emptyGroup => '(vazio)';

  @override
  String get total => 'Total';

  @override
  String get dropDimensionsHere => 'Solte as dimensões aqui';

  @override
  String get addDimension => 'Adicionar dimensão';

  @override
  String get addAggregate => 'Adicionar agregado';

  @override
  String get search => 'Pesquisar';

  @override
  String get alreadyInUse => 'já em uso';

  @override
  String get function => 'Função';

  @override
  String get expand => 'Expandir';

  @override
  String get largeExpansionTitle => 'Expansão grande';

  @override
  String get sortAscending => 'Ordenar crescente';

  @override
  String get sortDescending => 'Ordenar decrescente';

  @override
  String get expandAll => 'Expandir tudo';

  @override
  String get collapseAll => 'Recolher tudo';

  @override
  String largeExpansion(String label, int added, {required bool isRow}) =>
      'Expandir "$label" adiciona $added ${isRow ? 'linhas' : 'colunas'}. Continuar?';
}
