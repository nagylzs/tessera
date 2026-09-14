import '../cube/layout_aggregate.dart';
import '../expr/expr_type.dart';
import '../expr/expression_error.dart';
import '../facts/dimension.dart';
import 'tessera_strings.dart';

/// ru texts. Native review welcome.
final class TesseraStringsRu extends TesseraStrings {
  const TesseraStringsRu();

  @override
  String get languageCode => 'ru';

  @override
  String sumOf(String t) => 'сумма: $t';

  @override
  String averageOf(String t) => 'среднее: $t';

  @override
  String minimumOf(String t) => 'минимум: $t';

  @override
  String maximumOf(String t) => 'максимум: $t';

  @override
  String stdDevOf(String t) => 'стандартное отклонение: $t';

  @override
  String stdDevPopulationOf(String t) =>
      'стандартное отклонение (ген. совокупность): $t';

  @override
  String varianceOf(String t) => 'дисперсия: $t';

  @override
  String variancePopulationOf(String t) => 'дисперсия (ген. совокупность): $t';

  @override
  String countOf(String t) => 'количество: $t';

  @override
  String distinctCountOf(String t) => 'уникальные значения: $t';

  @override
  String get countLabel => 'количество';

  @override
  String percentOfTotal(String base, TotalOf of) => switch (of) {
    TotalOf.row => '$base % от итога строки',
    TotalOf.column => '$base % от итога столбца',
    TotalOf.grand => '$base % от общего итога',
    TotalOf.parentRow => '$base % от родительской строки',
    TotalOf.parentColumn => '$base % от родительского столбца',
  };

  @override
  String differenceFrom(String base, String item, {required bool percent}) =>
      percent ? '$base % отличия от $item' : '$base отличие от $item';

  @override
  String get previousItem => 'предыдущий';

  @override
  String get nextItem => 'следующий';

  @override
  String runningTotalOf(String base) => '$base нарастающий итог';

  @override
  String rankOf(String base) => '$base ранг';

  @override
  String get countOfFacts => 'Количество строк';

  @override
  String get sum => 'Сумма';

  @override
  String get average => 'Среднее';

  @override
  String get minimum => 'Минимум';

  @override
  String get maximum => 'Максимум';

  @override
  String get standardDeviation => 'Стандартное отклонение';

  @override
  String get populationStandardDeviation =>
      'Стандартное отклонение (ген. совокупность)';

  @override
  String get variance => 'Дисперсия';

  @override
  String get populationVariance => 'Дисперсия (ген. совокупность)';

  @override
  String get countOfValues => 'Количество значений';

  @override
  String get distinctCount => 'Количество уникальных значений';

  @override
  String datePartName(DatePart part) => switch (part) {
    DatePart.year => 'год',
    DatePart.quarter => 'квартал',
    DatePart.month => 'месяц',
    DatePart.week => 'неделя',
    DatePart.day => 'день',
    DatePart.weekday => 'день недели',
    DatePart.hour => 'час',
  };

  @override
  String datePartLabel(String column, DatePart part) {
    final p = datePartName(part);
    return '$column ($p)';
  }

  static const _months = [
    'январь',
    'февраль',
    'март',
    'апрель',
    'май',
    'июнь',
    'июль',
    'август',
    'сентябрь',
    'октябрь',
    'ноябрь',
    'декабрь',
  ];

  static const _weekdays = [
    'понедельник',
    'вторник',
    'среда',
    'четверг',
    'пятница',
    'суббота',
    'воскресенье',
  ];

  @override
  String monthName(int month) => _months[month - 1];

  @override
  String weekdayName(int weekday) => _weekdays[weekday - 1];

  @override
  String quarter(int q) => '$q кв.';

  @override
  String get decimalSeparator => ',';

  @override
  String get groupSeparator => '\u00A0';

  @override
  String get rows => 'Строки';

  @override
  String get columns => 'Столбцы';

  @override
  String get values => 'Значения';

  @override
  String get emptyGroup => '(пусто)';

  @override
  String get total => 'Итого';

  @override
  String get dropDimensionsHere => 'Перетащите измерения сюда';

  @override
  String get addDimension => 'Добавить измерение';

  @override
  String get addAggregate => 'Добавить агрегат';

  @override
  String get search => 'Поиск';

  @override
  String get alreadyInUse => 'уже используется';

  @override
  String get function => 'Функция';

  @override
  String get expand => 'Развернуть';

  @override
  String get largeExpansionTitle => 'Большое разворачивание';

  @override
  String get sortAscending => 'Сортировать по возрастанию';

  @override
  String get sortDescending => 'Сортировать по убыванию';

  @override
  String get inheritSort => 'Как на уровне выше';

  @override
  String get totalsAtEnd => 'Итоги в конце';

  @override
  String get totalsAtStart => 'Итоги в начале';

  @override
  String get totalsHidden => 'Скрыть итоги';

  @override
  String get subtotalsAbove => 'Промежуточные итоги над группой';

  @override
  String get subtotalsBelow => 'Промежуточные итоги под группой';

  @override
  String get subtotalsLeft => 'Промежуточные итоги слева от группы';

  @override
  String get subtotalsRight => 'Промежуточные итоги справа от группы';

  @override
  String get subtotalsHidden => 'Скрыть промежуточные итоги';

  @override
  String get expandAll => 'Развернуть всё';

  @override
  String get collapseAll => 'Свернуть всё';

  @override
  String largeExpansion(String label, int added, {required bool isRow}) =>
      'Разворачивание «$label» добавит $added ${isRow ? 'строк' : 'столбцов'}. Продолжить?';

  @override
  String get filter => 'Фильтр';

  @override
  String get noFilter => 'Без фильтра';

  @override
  String get addCondition => 'Добавить условие';

  @override
  String get addGroup => 'Добавить группу';

  @override
  String get addExpression => 'Добавить выражение';

  @override
  String get matchAll => 'Все условия';

  @override
  String get matchAny => 'Любое из условий';

  @override
  String get negate => 'Не';

  @override
  String get opEquals => 'равно';

  @override
  String get opNotEquals => 'не равно';

  @override
  String get opLess => 'меньше';

  @override
  String get opLessOrEqual => 'не больше';

  @override
  String get opGreater => 'больше';

  @override
  String get opGreaterOrEqual => 'не меньше';

  @override
  String get opBetween => 'между';

  @override
  String get opContains => 'содержит';

  @override
  String get opStartsWith => 'начинается с';

  @override
  String get opEndsWith => 'заканчивается на';

  @override
  String get opIsEmpty => 'пусто';

  @override
  String get opIsNotEmpty => 'не пусто';

  @override
  String get opIsOneOf => 'одно из';

  @override
  String get opIsTrue => 'истина';

  @override
  String get opIsFalse => 'ложь';

  @override
  String get customFilter => 'Пользовательский фильтр';

  @override
  String get expression => 'Выражение';

  @override
  String get selectValues => 'Выбрать значения…';

  @override
  String selectedCount(int count) => 'выбрано: $count';

  @override
  String get clear => 'Очистить';

  @override
  String get apply => 'Применить';

  @override
  String get column => 'Столбец';

  @override
  String get value => 'Значение';

  @override
  String exprTypeName(ExprType type) => switch (type) {
    ExprType.number => 'число',
    ExprType.text => 'текст',
    ExprType.boolean => 'логическое',
    ExprType.date => 'дата',
  };

  @override
  String expressionErrorText(
    ExpressionErrorKind kind,
    List<String> a,
  ) => switch (kind) {
    ExpressionErrorKind.unexpectedCharacter => 'неожиданный символ «${a[0]}»',
    ExpressionErrorKind.unterminatedText => 'незакрытый текст',
    ExpressionErrorKind.unterminatedName => 'после имени столбца нет «]»',
    ExpressionErrorKind.unterminatedDate => 'после даты нет «#»',
    ExpressionErrorKind.invalidNumber => 'неверное число «${a[0]}»',
    ExpressionErrorKind.invalidDate => 'неверная дата «${a[0]}»',
    ExpressionErrorKind.unexpectedToken => 'неожиданное «${a[0]}»',
    ExpressionErrorKind.unexpectedEnd => 'неожиданный конец выражения',
    ExpressionErrorKind.unknownColumn => 'неизвестный столбец «${a[0]}»',
    ExpressionErrorKind.unknownFunction => 'неизвестная функция «${a[0]}»',
    ExpressionErrorKind.argumentCount =>
      '${a[0]} ожидает аргументов: ${a[1]}, передано ${a[2]}',
    ExpressionErrorKind.argumentType =>
      'аргумент ${a[1]} функции ${a[0]} должен быть типа ${a[2]}, а не ${a[3]}',
    ExpressionErrorKind.operandType =>
      'операнд ${a[0]} должен быть типа ${a[1]}, а не ${a[2]}',
    ExpressionErrorKind.incompatibleTypes =>
      '${a[0]} неприменимо к ${a[1]} и ${a[2]}',
    ExpressionErrorKind.unknownType => 'невозможно определить тип',
    ExpressionErrorKind.notAllowedHere => '«${a[0]}» здесь недопустимо',
    ExpressionErrorKind.resultType =>
      'выражение должно быть типа ${a[0]}, а не ${a[1]}',
  };
}
