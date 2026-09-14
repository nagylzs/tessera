import '../facts/dimension.dart';
import 'tessera_strings.dart';

/// en texts. Native review welcome.
final class TesseraStringsEn extends TesseraStrings {
  const TesseraStringsEn();

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
  String stdDevOf(String t) => 'std dev of $t';

  @override
  String stdDevPopulationOf(String t) => 'population std dev of $t';

  @override
  String varianceOf(String t) => 'variance of $t';

  @override
  String variancePopulationOf(String t) => 'population variance of $t';

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
  String get standardDeviation => 'Standard deviation';

  @override
  String get populationStandardDeviation => 'Population standard deviation';

  @override
  String get variance => 'Variance';

  @override
  String get populationVariance => 'Population variance';

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
  String get sortAscending => 'Sort ascending';

  @override
  String get sortDescending => 'Sort descending';

  @override
  String get inheritSort => 'Same order as the level above';

  @override
  String get totalsAtEnd => 'Totals at the end';

  @override
  String get totalsAtStart => 'Totals at the start';

  @override
  String get totalsHidden => 'Hide totals';

  @override
  String get subtotalsAbove => 'Subtotals above the group';

  @override
  String get subtotalsBelow => 'Subtotals below the group';

  @override
  String get subtotalsLeft => 'Subtotals left of the group';

  @override
  String get subtotalsRight => 'Subtotals right of the group';

  @override
  String get subtotalsHidden => 'Hide subtotals';

  @override
  String get expandAll => 'Expand all';

  @override
  String get collapseAll => 'Collapse all';

  @override
  String largeExpansion(String label, int added, {required bool isRow}) =>
      'Expanding "$label" adds $added ${isRow ? 'rows' : 'columns'}. Continue?';
}
