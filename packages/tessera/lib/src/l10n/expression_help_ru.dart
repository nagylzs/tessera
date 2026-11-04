import 'expression_help.dart';

/// ru texts of the expression help. Native review welcome.
final class ExpressionHelpStringsRu extends ExpressionHelpStrings {
  const ExpressionHelpStringsRu();

  @override
  String get languageCode => 'ru';

  @override
  String get title => 'Справка по выражениям';

  @override
  String get tapToInsert =>
      'Пример, столбец или функцию можно вставить нажатием.';

  @override
  String intro(ExpressionHelpUse use) => switch (use) {
    ExpressionHelpUse.filter =>
      'Фильтр оставляет строки, для которых выражение истинно. '
          'Условия объединяются операторами and, or и not.',
    ExpressionHelpUse.measure =>
      'Вычисляемая мера рассчитывается для каждой строки из её '
          'столбцов, а затем суммируется или усредняется, как столбец.',
    ExpressionHelpUse.dimension =>
      'Вычисляемое измерение группирует строки по значению '
          'выражения, как это сделал бы столбец. Значением может быть '
          'число, текст, дата или истина/ложь.',
    ExpressionHelpUse.formula =>
      'Формула ячейки вычисляется в каждой ячейке сводной таблицы из '
          'агрегатов этой ячейки, например sum(x) или count.',
  };

  @override
  String get examples => 'Примеры';

  @override
  String get columns => 'Столбцы';

  @override
  String get aggregates => 'Агрегаты';

  @override
  String get operators => 'Операторы';

  @override
  String get values => 'Значения';

  @override
  String get rules => 'Правила';

  @override
  String get functions => 'Функции';

  @override
  String get aggregateArgument =>
      'x — столбец или вычисление над столбцами строки: sum(quantity '
      '* price). count без аргумента считает строки.';

  @override
  String groupName(ExpressionHelpGroup group) => switch (group) {
    ExpressionHelpGroup.conditional => 'Условия',
    ExpressionHelpGroup.numbers => 'Числа',
    ExpressionHelpGroup.text => 'Текст',
    ExpressionHelpGroup.dates => 'Даты',
    ExpressionHelpGroup.other => 'Другие функции',
  };

  @override
  String operatorText(ExpressionHelpOperator operator) => switch (operator) {
    ExpressionHelpOperator.arithmetic =>
      'Сложение, вычитание, умножение, деление. Деление на ноль даёт '
          'пустое значение.',
    ExpressionHelpOperator.remainder => 'Остаток от деления: 7 % 3 равно 1.',
    ExpressionHelpOperator.comparison =>
      'Равно, не равно, меньше, меньше или равно, больше, больше или '
          'равно. Также работают == и !=.',
    ExpressionHelpOperator.logic =>
      'Оба условия, хотя бы одно из них, отрицание.',
    ExpressionHelpOperator.inList =>
      'x равно одному из перечисленных значений или ни одному из них.',
    ExpressionHelpOperator.between => 'a ≤ x ≤ b, оба конца включены.',
    ExpressionHelpOperator.emptyTest => 'x не имеет значения или имеет его.',
    ExpressionHelpOperator.dates =>
      'n дней после даты или до неё; число дней между двумя датами.',
  };

  @override
  String literalText(ExpressionHelpLiteral literal) => switch (literal) {
    ExpressionHelpLiteral.number =>
      'Числа, всегда с десятичной точкой: 12.5, а не 12,5.',
    ExpressionHelpLiteral.text =>
      'Текст в двойных или одинарных кавычках. Кавычка внутри текста '
          'удваивается: "say ""hi""".',
    ExpressionHelpLiteral.date =>
      'Даты, при необходимости со временем, между знаками #, сначала '
          'год.',
    ExpressionHelpLiteral.boolean => 'Логические значения.',
    ExpressionHelpLiteral.empty => 'Пустое значение.',
    ExpressionHelpLiteral.name =>
      'Имя столбца с пробелами или знаками препинания, а также '
          'совпадающее с ключевым словом, заключается в квадратные '
          'скобки.',
  };

  @override
  String ruleText(ExpressionHelpRule rule) => switch (rule) {
    ExpressionHelpRule.emptyValues =>
      'Вычисление или сравнение с пустым значением даёт пустое '
          'значение: price * 2 и price > 0 пусты там, где пуст столбец '
          'price. coalesce(price, 0) подставляет 0 вместо пустого '
          'значения; price is empty находит строки без цены.',
    ExpressionHelpRule.filters =>
      'Фильтр оставляет строку, только если её выражение истинно: '
          'discount > 0 отбрасывает строки без скидки, а discount > 0 or '
          'discount is empty оставляет их.',
    ExpressionHelpRule.letterCase =>
      'Имена функций и ключевые слова можно писать в любом регистре '
          '(YEAR, Year); имена столбцов должны совпадать точно. '
          'Сравнение текста учитывает регистр: чтобы не учитывать его, '
          'сравнивайте lower(x).',
  };

  @override
  ({String signature, String description}) function(
    ExpressionHelpFunction function,
  ) => switch (function) {
    ExpressionHelpFunction.ifElse => (
      signature: 'if(условие, a, b)',
      description:
          'Значение a, если условие истинно, иначе b (в том числе если '
          'условие пусто). Аргументы a и b одного типа.',
    ),
    ExpressionHelpFunction.coalesce => (
      signature: 'coalesce(a, b, …)',
      description: 'Первый из аргументов, который не пуст.',
    ),
    ExpressionHelpFunction.isempty => (
      signature: 'isempty(x)',
      description: 'Истина, если значение x пусто; то же, что x is empty.',
    ),
    ExpressionHelpFunction.abs => (
      signature: 'abs(x)',
      description: 'Значение x без знака.',
    ),
    ExpressionHelpFunction.round => (
      signature: 'round(x, знаки)',
      description:
          'x, округлённое до числа десятичных знаков, заданного '
          'аргументом знаки; без него — до целого. Отрицательный '
          'аргумент знаки округляет до десятков, сотен…: round(1234.5, '
          '-2) равно 1200.',
    ),
    ExpressionHelpFunction.floor => (
      signature: 'floor(x)',
      description:
          'x, округлённое вниз до целого: floor(2.7) равно 2, '
          'floor(-2.5) равно -3.',
    ),
    ExpressionHelpFunction.ceil => (
      signature: 'ceil(x)',
      description: 'x, округлённое вверх до целого: ceil(2.1) равно 3.',
    ),
    ExpressionHelpFunction.sqrt => (
      signature: 'sqrt(x)',
      description: 'Квадратный корень из x; пусто, если x меньше нуля.',
    ),
    ExpressionHelpFunction.min => (
      signature: 'min(x, y, …)',
      description: 'Наименьшее из чисел; пустые пропускаются.',
    ),
    ExpressionHelpFunction.max => (
      signature: 'max(x, y, …)',
      description: 'Наибольшее из чисел; пустые пропускаются.',
    ),
    ExpressionHelpFunction.number => (
      signature: 'number(текст)',
      description:
          'Число, записанное в тексте с десятичной точкой; пусто, если '
          'текст не является числом.',
    ),
    ExpressionHelpFunction.len => (
      signature: 'len(текст)',
      description: 'Количество символов в тексте.',
    ),
    ExpressionHelpFunction.lower => (
      signature: 'lower(текст)',
      description: 'Текст в нижнем регистре.',
    ),
    ExpressionHelpFunction.upper => (
      signature: 'upper(текст)',
      description: 'Текст в верхнем регистре.',
    ),
    ExpressionHelpFunction.trim => (
      signature: 'trim(текст)',
      description: 'Текст без пробелов в начале и в конце.',
    ),
    ExpressionHelpFunction.left => (
      signature: 'left(текст, n)',
      description: 'Первые n символов текста.',
    ),
    ExpressionHelpFunction.right => (
      signature: 'right(текст, n)',
      description: 'Последние n символов текста.',
    ),
    ExpressionHelpFunction.substring => (
      signature: 'substring(текст, начало, длина)',
      description:
          'Столько символов текста, сколько задаёт длина, начиная с '
          'позиции начало (первый символ — 1); без аргумента длина — '
          'остаток текста.',
    ),
    ExpressionHelpFunction.contains => (
      signature: 'contains(текст, часть)',
      description: 'Истина, если часть встречается в тексте.',
    ),
    ExpressionHelpFunction.startswith => (
      signature: 'startswith(текст, часть)',
      description: 'Истина, если часть стоит в начале текста.',
    ),
    ExpressionHelpFunction.endswith => (
      signature: 'endswith(текст, часть)',
      description: 'Истина, если часть стоит в конце текста.',
    ),
    ExpressionHelpFunction.replace => (
      signature: 'replace(текст, старое, новое)',
      description: 'Текст, в котором каждое старое заменено на новое.',
    ),
    ExpressionHelpFunction.concat => (
      signature: 'concat(a, b, …)',
      description:
          'Соединённые тексты; пустые пропускаются. text(x) превращает '
          'число или дату в текст.',
    ),
    ExpressionHelpFunction.text => (
      signature: 'text(x)',
      description:
          'Число, дата или истина/ложь в виде текста: text(1.5) равно '
          '"1.5", text(#2024-01-31#) равно "2024-01-31".',
    ),
    ExpressionHelpFunction.year => (
      signature: 'year(дата)',
      description: 'Год даты.',
    ),
    ExpressionHelpFunction.quarter => (
      signature: 'quarter(дата)',
      description: 'Квартал года, от 1 до 4.',
    ),
    ExpressionHelpFunction.month => (
      signature: 'month(дата)',
      description: 'Месяц, от 1 до 12.',
    ),
    ExpressionHelpFunction.week => (
      signature: 'week(дата)',
      description: 'Номер недели по ISO, от 1 до 53.',
    ),
    ExpressionHelpFunction.day => (
      signature: 'day(дата)',
      description: 'День месяца, от 1 до 31.',
    ),
    ExpressionHelpFunction.weekday => (
      signature: 'weekday(дата)',
      description: 'День недели, от 1 (понедельник) до 7 (воскресенье).',
    ),
    ExpressionHelpFunction.hour => (
      signature: 'hour(дата)',
      description: 'Час, от 0 до 23.',
    ),
    ExpressionHelpFunction.dateOfText => (
      signature: 'date(текст)',
      description:
          'Дата, записанная в тексте, сначала год: date("2024-01-31"); '
          'пусто, если текст не является датой.',
    ),
    ExpressionHelpFunction.dateOfParts => (
      signature: 'date(год, месяц, день)',
      description: 'Дата из заданных года, месяца и дня.',
    ),
    ExpressionHelpFunction.today => (
      signature: 'today()',
      description: 'Сегодняшняя дата.',
    ),
  };
}
