import '../facts/dimension.dart';
import 'tessera_localizations.dart';

/// en texts. Native review welcome.
final class TesseraLocalizationsEn extends TesseraLocalizations {
  const TesseraLocalizationsEn();

  @override
  String get languageCode => 'en';

  @override
  String sumOf(String t) => 'sum of $t';

  @override
  String averageOf(String t) => 'avg of $t';

  @override
  String minimumOf(String t) => 'min of $t';

  @override
  String maximumOf(String t) => 'max of $t';

  @override
  String countOf(String t) => 'count of $t';

  @override
  String distinctCountOf(String t) => 'distinct $t';

  @override
  String get countLabel => 'count';

  @override
  String get countOfFacts => 'Count of facts';

  @override
  String get sum => 'Sum';

  @override
  String get average => 'Average';

  @override
  String get minimum => 'Minimum';

  @override
  String get maximum => 'Maximum';

  @override
  String get countOfValues => 'Count of values';

  @override
  String get distinctCount => 'Distinct count';

  @override
  String datePartName(DatePart part) => switch (part) {
    DatePart.year => 'year',
    DatePart.quarter => 'quarter',
    DatePart.month => 'month',
    DatePart.week => 'week',
    DatePart.day => 'day',
    DatePart.weekday => 'weekday',
    DatePart.hour => 'hour',
  };

  @override
  String datePartLabel(String column, DatePart part) {
    final p = datePartName(part);
    return '$column $p';
  }

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  String monthName(int month) => _months[month - 1];

  @override
  String weekdayName(int weekday) => _weekdays[weekday - 1];

  @override
  String quarter(int q) => 'Q$q';

  @override
  String get decimalSeparator => '.';

  @override
  String get groupSeparator => ',';

  @override
  String get rows => 'Rows';

  @override
  String get columns => 'Columns';

  @override
  String get values => 'Values';

  @override
  String get emptyGroup => '(empty)';

  @override
  String get total => 'Total';

  @override
  String get dropDimensionsHere => 'Drop dimensions here';

  @override
  String get addDimension => 'Add dimension';

  @override
  String get addAggregate => 'Add aggregate';

  @override
  String get search => 'Search';

  @override
  String get alreadyInUse => 'already in use';

  @override
  String get function => 'Function';

  @override
  String get expand => 'Expand';

  @override
  String get largeExpansionTitle => 'Large expansion';

  @override
  String largeExpansion(String label, int added, {required bool isRow}) =>
      'Expanding "$label" adds $added ${isRow ? 'rows' : 'columns'}. Continue?';
}
