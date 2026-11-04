import 'expression_help.dart';

/// pt texts of the expression help. Native review welcome.
final class ExpressionHelpStringsPt extends ExpressionHelpStrings {
  const ExpressionHelpStringsPt();

  @override
  String get languageCode => 'pt';

  @override
  String get title => 'Ajuda sobre expressões';

  @override
  String get tapToInsert =>
      'Toque em um exemplo, uma coluna ou uma função para inseri-lo.';

  @override
  String intro(ExpressionHelpUse use) => switch (use) {
    ExpressionHelpUse.filter =>
      'Um filtro mantém as linhas para as quais a expressão é verdadeira. '
          'Combine as condições com and, or e not.',
    ExpressionHelpUse.measure =>
      'Uma medida calculada é avaliada em cada linha a partir de suas '
          'colunas; depois, calcula-se a soma ou a média, como para uma '
          'coluna.',
    ExpressionHelpUse.dimension =>
      'Uma dimensão calculada agrupa as linhas pelo valor da expressão, '
          'como faria uma coluna: um número, um texto, uma data ou '
          'true/false.',
    ExpressionHelpUse.formula =>
      'Uma fórmula de célula é calculada em cada célula da tabela dinâmica a '
          'partir dos agregados da célula, como sum(x) ou count.',
  };

  @override
  String get examples => 'Exemplos';

  @override
  String get columns => 'Colunas';

  @override
  String get aggregates => 'Agregados';

  @override
  String get operators => 'Operadores';

  @override
  String get values => 'Valores';

  @override
  String get rules => 'Regras';

  @override
  String get functions => 'Funções';

  @override
  String get aggregateArgument =>
      'x é uma coluna ou um cálculo sobre as colunas de uma linha: '
      'sum(quantity * price). count sozinho conta as linhas.';

  @override
  String groupName(ExpressionHelpGroup group) => switch (group) {
    ExpressionHelpGroup.conditional => 'Condições',
    ExpressionHelpGroup.numbers => 'Números',
    ExpressionHelpGroup.text => 'Texto',
    ExpressionHelpGroup.dates => 'Datas',
    ExpressionHelpGroup.other => 'Outras funções',
  };

  @override
  String operatorText(ExpressionHelpOperator operator) => switch (operator) {
    ExpressionHelpOperator.arithmetic =>
      'Adição, subtração, multiplicação, divisão. Dividir por zero dá um '
          'valor vazio.',
    ExpressionHelpOperator.remainder => 'O resto de uma divisão: 7 % 3 é 1.',
    ExpressionHelpOperator.comparison =>
      'Igual, diferente, menor, menor ou igual, maior, maior ou igual. '
          '== e != também funcionam.',
    ExpressionHelpOperator.logic =>
      'Ambas as condições, qualquer uma delas, o contrário.',
    ExpressionHelpOperator.inList =>
      'x é um dos valores listados, ou nenhum deles.',
    ExpressionHelpOperator.between => 'a ≤ x ≤ b, ambos os extremos incluídos.',
    ExpressionHelpOperator.emptyTest => 'x não tem valor, ou tem um.',
    ExpressionHelpOperator.dates =>
      'n dias depois ou antes de uma data; os dias entre duas datas.',
  };

  @override
  String literalText(ExpressionHelpLiteral literal) => switch (literal) {
    ExpressionHelpLiteral.number =>
      'Números, sempre com ponto decimal: 12.5, não 12,5.',
    ExpressionHelpLiteral.text =>
      'Texto entre aspas duplas ou simples. Uma aspa dentro do texto é '
          'duplicada: "say ""hi""".',
    ExpressionHelpLiteral.date =>
      'Datas, com hora se necessário, entre dois sinais #, o ano primeiro.',
    ExpressionHelpLiteral.boolean => 'Valores lógicos.',
    ExpressionHelpLiteral.empty => 'O valor vazio.',
    ExpressionHelpLiteral.name =>
      'Um nome de coluna com espaços ou pontuação, ou escrito como uma '
          'palavra-chave, vai entre colchetes.',
  };

  @override
  String ruleText(ExpressionHelpRule rule) => switch (rule) {
    ExpressionHelpRule.emptyValues =>
      'Um cálculo ou uma comparação com um valor vazio é vazio: '
          'price * 2 e price > 0 ficam vazios onde o preço está vazio. '
          'coalesce(price, 0) usa 0 no lugar; price is empty encontra as '
          'linhas sem preço.',
    ExpressionHelpRule.filters =>
      'Um filtro mantém uma linha somente onde sua expressão é verdadeira: '
          'discount > 0 descarta as linhas sem desconto, '
          'discount > 0 or discount is empty as mantém.',
    ExpressionHelpRule.letterCase =>
      'Nomes de funções e palavras-chave não diferenciam maiúsculas de '
          'minúsculas (YEAR, Year); nomes de colunas devem corresponder '
          'exatamente. Comparações de texto diferenciam maiúsculas de '
          'minúsculas: compare lower(x) para ignorar essa diferença.',
  };

  @override
  ({String signature, String description}) function(
    ExpressionHelpFunction function,
  ) => switch (function) {
    ExpressionHelpFunction.ifElse => (
      signature: 'if(condição, a, b)',
      description:
          'Onde a condição é verdadeira, a; senão, b (também onde a condição '
          'está vazia). a e b são do mesmo tipo.',
    ),
    ExpressionHelpFunction.coalesce => (
      signature: 'coalesce(a, b, …)',
      description: 'O primeiro de seus argumentos que não está vazio.',
    ),
    ExpressionHelpFunction.isempty => (
      signature: 'isempty(x)',
      description: 'Verdadeiro onde x está vazio, o mesmo que x is empty.',
    ),
    ExpressionHelpFunction.abs => (
      signature: 'abs(x)',
      description: 'x sem o sinal.',
    ),
    ExpressionHelpFunction.round => (
      signature: 'round(x, decimais)',
      description:
          'x arredondado a tantas casas decimais quanto indicar decimais; '
          'sem decimais, a um número inteiro. Se decimais for negativo, '
          'arredonda para dezenas, centenas…: round(1234.5, -2) é 1200.',
    ),
    ExpressionHelpFunction.floor => (
      signature: 'floor(x)',
      description:
          'x arredondado para o inteiro abaixo: floor(2.7) é 2, '
          'floor(-2.5) é -3.',
    ),
    ExpressionHelpFunction.ceil => (
      signature: 'ceil(x)',
      description: 'x arredondado para o inteiro acima: ceil(2.1) é 3.',
    ),
    ExpressionHelpFunction.sqrt => (
      signature: 'sqrt(x)',
      description: 'A raiz quadrada de x; vazio para um x negativo.',
    ),
    ExpressionHelpFunction.min => (
      signature: 'min(x, y, …)',
      description: 'O menor dos números, ignorando os vazios.',
    ),
    ExpressionHelpFunction.max => (
      signature: 'max(x, y, …)',
      description: 'O maior dos números, ignorando os vazios.',
    ),
    ExpressionHelpFunction.number => (
      signature: 'number(texto)',
      description:
          'O número escrito em um texto, com ponto decimal; vazio se o texto '
          'não for um número.',
    ),
    ExpressionHelpFunction.len => (
      signature: 'len(texto)',
      description: 'O número de caracteres do texto.',
    ),
    ExpressionHelpFunction.lower => (
      signature: 'lower(texto)',
      description: 'O texto em minúsculas.',
    ),
    ExpressionHelpFunction.upper => (
      signature: 'upper(texto)',
      description: 'O texto em maiúsculas.',
    ),
    ExpressionHelpFunction.trim => (
      signature: 'trim(texto)',
      description: 'O texto sem espaços no início e no fim.',
    ),
    ExpressionHelpFunction.left => (
      signature: 'left(texto, n)',
      description: 'Os primeiros n caracteres do texto.',
    ),
    ExpressionHelpFunction.right => (
      signature: 'right(texto, n)',
      description: 'Os últimos n caracteres do texto.',
    ),
    ExpressionHelpFunction.substring => (
      signature: 'substring(texto, início, comprimento)',
      description:
          'comprimento caracteres do texto a partir da posição início, sendo '
          '1 o primeiro caractere; sem comprimento, o resto do texto.',
    ),
    ExpressionHelpFunction.contains => (
      signature: 'contains(texto, parte)',
      description: 'Verdadeiro onde parte aparece no texto.',
    ),
    ExpressionHelpFunction.startswith => (
      signature: 'startswith(texto, parte)',
      description: 'Verdadeiro onde o texto começa com parte.',
    ),
    ExpressionHelpFunction.endswith => (
      signature: 'endswith(texto, parte)',
      description: 'Verdadeiro onde o texto termina com parte.',
    ),
    ExpressionHelpFunction.replace => (
      signature: 'replace(texto, antigo, novo)',
      description: 'O texto com cada antigo substituído por novo.',
    ),
    ExpressionHelpFunction.concat => (
      signature: 'concat(a, b, …)',
      description:
          'Os textos unidos, ignorando os vazios. text(x) converte um número '
          'ou uma data em texto.',
    ),
    ExpressionHelpFunction.text => (
      signature: 'text(x)',
      description:
          'Um número, uma data ou true/false como texto: text(1.5) é "1.5", '
          'text(#2024-01-31#) é "2024-01-31".',
    ),
    ExpressionHelpFunction.year => (
      signature: 'year(data)',
      description: 'O ano da data.',
    ),
    ExpressionHelpFunction.quarter => (
      signature: 'quarter(data)',
      description: 'O trimestre do ano, de 1 a 4.',
    ),
    ExpressionHelpFunction.month => (
      signature: 'month(data)',
      description: 'O mês, de 1 a 12.',
    ),
    ExpressionHelpFunction.week => (
      signature: 'week(data)',
      description: 'O número da semana ISO, de 1 a 53.',
    ),
    ExpressionHelpFunction.day => (
      signature: 'day(data)',
      description: 'O dia do mês, de 1 a 31.',
    ),
    ExpressionHelpFunction.weekday => (
      signature: 'weekday(data)',
      description: 'O dia da semana, de 1 (segunda-feira) a 7 (domingo).',
    ),
    ExpressionHelpFunction.hour => (
      signature: 'hour(data)',
      description: 'A hora, de 0 a 23.',
    ),
    ExpressionHelpFunction.dateOfText => (
      signature: 'date(texto)',
      description:
          'A data escrita em um texto, o ano primeiro: date("2024-01-31"); '
          'vazio se o texto não for uma data.',
    ),
    ExpressionHelpFunction.dateOfParts => (
      signature: 'date(ano, mês, dia)',
      description: 'A data do ano, mês e dia informados.',
    ),
    ExpressionHelpFunction.today => (
      signature: 'today()',
      description: 'A data de hoje.',
    ),
  };
}
