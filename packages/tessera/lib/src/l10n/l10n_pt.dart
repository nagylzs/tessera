import '../cube/layout_aggregate.dart';
import '../expr/expr_type.dart';
import '../expr/expression_error.dart';
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
  String stdDevOf(String t) => 'desvio padrão de $t';

  @override
  String stdDevPopulationOf(String t) => 'desvio padrão populacional de $t';

  @override
  String varianceOf(String t) => 'variância de $t';

  @override
  String variancePopulationOf(String t) => 'variância populacional de $t';

  @override
  String countOf(String t) => 'contagem de $t';

  @override
  String distinctCountOf(String t) => 'valores distintos de $t';

  @override
  String get countLabel => 'contagem';

  @override
  String percentOfTotal(String base, TotalOf of) => switch (of) {
    TotalOf.row => '$base % do total da linha',
    TotalOf.column => '$base % do total da coluna',
    TotalOf.grand => '$base % do total geral',
    TotalOf.parentRow => '$base % da linha principal',
    TotalOf.parentColumn => '$base % da coluna principal',
  };

  @override
  String differenceFrom(String base, String item, {required bool percent}) =>
      percent ? '$base % de diferença de $item' : '$base diferença de $item';

  @override
  String get previousItem => 'anterior';

  @override
  String get nextItem => 'seguinte';

  @override
  String runningTotalOf(String base) => '$base total acumulado';

  @override
  String rankOf(String base) => '$base classificação';

  @override
  String get showValuesAs => 'Mostrar valores como';

  @override
  String valueDisplayName(ValueDisplay display) => switch (display) {
    ValueDisplay.plain => 'Valor simples',
    ValueDisplay.percentOfRow => '% do total da linha',
    ValueDisplay.percentOfColumn => '% do total da coluna',
    ValueDisplay.percentOfGrand => '% do total geral',
    ValueDisplay.percentOfParentRow => '% da linha principal',
    ValueDisplay.percentOfParentColumn => '% da coluna principal',
    ValueDisplay.differenceFromPreviousRow => 'Diferença da linha anterior',
    ValueDisplay.differenceFromPreviousColumn => 'Diferença da coluna anterior',
    ValueDisplay.percentDifferenceFromPreviousRow =>
      '% de diferença da linha anterior',
    ValueDisplay.percentDifferenceFromPreviousColumn =>
      '% de diferença da coluna anterior',
    ValueDisplay.runningTotalRows => 'Total acumulado por linhas',
    ValueDisplay.runningTotalColumns => 'Total acumulado por colunas',
    ValueDisplay.rankRows => 'Classificação entre linhas',
    ValueDisplay.rankColumns => 'Classificação entre colunas',
  };

  @override
  String get formula => 'Fórmula';

  @override
  String get labelField => 'Rótulo';

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
  String get standardDeviation => 'Desvio padrão';

  @override
  String get populationStandardDeviation => 'Desvio padrão populacional';

  @override
  String get variance => 'Variância';

  @override
  String get populationVariance => 'Variância populacional';

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
  String get inheritSort => 'Mesma ordem do nível acima';

  @override
  String get totalsAtEnd => 'Totais no fim';

  @override
  String get totalsAtStart => 'Totais no início';

  @override
  String get totalsHidden => 'Ocultar totais';

  @override
  String get subtotalsAbove => 'Subtotais acima do grupo';

  @override
  String get subtotalsBelow => 'Subtotais abaixo do grupo';

  @override
  String get subtotalsLeft => 'Subtotais à esquerda do grupo';

  @override
  String get subtotalsRight => 'Subtotais à direita do grupo';

  @override
  String get subtotalsHidden => 'Ocultar subtotais';

  @override
  String get expandAll => 'Expandir tudo';

  @override
  String get collapseAll => 'Recolher tudo';

  @override
  String largeExpansion(String label, int added, {required bool isRow}) =>
      'Expandir "$label" adiciona $added ${isRow ? 'linhas' : 'colunas'}. Continuar?';

  @override
  String get filter => 'Filtro';

  @override
  String get noFilter => 'Sem filtro';

  @override
  String get addCondition => 'Adicionar condição';

  @override
  String get addGroup => 'Adicionar grupo';

  @override
  String get addExpression => 'Adicionar expressão';

  @override
  String get matchAll => 'Todas as condições';

  @override
  String get matchAny => 'Qualquer uma das condições';

  @override
  String get negate => 'Não';

  @override
  String get opEquals => 'é igual a';

  @override
  String get opNotEquals => 'é diferente de';

  @override
  String get opLess => 'é menor que';

  @override
  String get opLessOrEqual => 'é no máximo';

  @override
  String get opGreater => 'é maior que';

  @override
  String get opGreaterOrEqual => 'é no mínimo';

  @override
  String get opBetween => 'está entre';

  @override
  String get opContains => 'contém';

  @override
  String get opStartsWith => 'começa com';

  @override
  String get opEndsWith => 'termina com';

  @override
  String get opIsEmpty => 'está vazio';

  @override
  String get opIsNotEmpty => 'não está vazio';

  @override
  String get opIsOneOf => 'é um de';

  @override
  String get opIsTrue => 'é verdadeiro';

  @override
  String get opIsFalse => 'é falso';

  @override
  String get customFilter => 'Filtro personalizado';

  @override
  String get expression => 'Expressão';

  @override
  String get selectValues => 'Selecionar valores…';

  @override
  String selectedCount(int count) => '$count selecionados';

  @override
  String get clear => 'Limpar';

  @override
  String get apply => 'Aplicar';

  @override
  String get column => 'Coluna';

  @override
  String get value => 'Valor';

  @override
  String exprTypeName(ExprType type) => switch (type) {
    ExprType.number => 'número',
    ExprType.text => 'texto',
    ExprType.boolean => 'booleano',
    ExprType.date => 'data',
  };

  @override
  String expressionErrorText(
    ExpressionErrorKind kind,
    List<String> a,
  ) => switch (kind) {
    ExpressionErrorKind.unexpectedCharacter => 'caractere inesperado "${a[0]}"',
    ExpressionErrorKind.unterminatedText => 'texto não terminado',
    ExpressionErrorKind.unterminatedName => 'falta "]" após o nome da coluna',
    ExpressionErrorKind.unterminatedDate => 'falta "#" após a data',
    ExpressionErrorKind.invalidNumber => 'número inválido "${a[0]}"',
    ExpressionErrorKind.invalidDate => 'data inválida "${a[0]}"',
    ExpressionErrorKind.unexpectedToken => '"${a[0]}" inesperado',
    ExpressionErrorKind.unexpectedEnd => 'fim inesperado da expressão',
    ExpressionErrorKind.unknownColumn => 'coluna desconhecida "${a[0]}"',
    ExpressionErrorKind.unknownFunction => 'função desconhecida "${a[0]}"',
    ExpressionErrorKind.argumentCount =>
      '${a[0]} espera ${a[1]} argumento(s), ${a[2]} fornecido(s)',
    ExpressionErrorKind.argumentType =>
      'o argumento ${a[1]} de ${a[0]} deve ser ${a[2]}, não ${a[3]}',
    ExpressionErrorKind.operandType =>
      'o operando de ${a[0]} deve ser ${a[1]}, não ${a[2]}',
    ExpressionErrorKind.incompatibleTypes =>
      'não é possível aplicar ${a[0]} a ${a[1]} e ${a[2]}',
    ExpressionErrorKind.unknownType => 'não é possível determinar o tipo',
    ExpressionErrorKind.notAllowedHere => '"${a[0]}" não é permitido aqui',
    ExpressionErrorKind.resultType =>
      'a expressão deve ser ${a[0]}, não ${a[1]}',
  };
}
