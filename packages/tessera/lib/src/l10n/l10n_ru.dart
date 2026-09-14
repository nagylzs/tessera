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
}
