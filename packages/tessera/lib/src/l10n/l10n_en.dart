import '../cube/layout_aggregate.dart';
import '../expr/expr_type.dart';
import '../expr/expression_error.dart';
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
  String percentOfTotal(String base, TotalOf of) => switch (of) {
    TotalOf.row => '$base % of row total',
    TotalOf.column => '$base % of column total',
    TotalOf.grand => '$base % of grand total',
    TotalOf.parentRow => '$base % of parent row',
    TotalOf.parentColumn => '$base % of parent column',
  };

  @override
  String differenceFrom(String base, String item, {required bool percent}) =>
      percent ? '$base % difference from $item' : '$base difference from $item';

  @override
  String get previousItem => 'previous';

  @override
  String get nextItem => 'next';

  @override
  String runningTotalOf(String base) => '$base running total';

  @override
  String rankOf(String base) => '$base rank';

  @override
  String get showValuesAs => 'Show values as';

  @override
  String valueDisplayName(ValueDisplay display) => switch (display) {
    ValueDisplay.plain => 'Plain value',
    ValueDisplay.percentOfRow => '% of row total',
    ValueDisplay.percentOfColumn => '% of column total',
    ValueDisplay.percentOfGrand => '% of grand total',
    ValueDisplay.percentOfParentRow => '% of parent row',
    ValueDisplay.percentOfParentColumn => '% of parent column',
    ValueDisplay.differenceFromPreviousRow => 'Difference from previous row',
    ValueDisplay.differenceFromPreviousColumn =>
      'Difference from previous column',
    ValueDisplay.percentDifferenceFromPreviousRow =>
      '% difference from previous row',
    ValueDisplay.percentDifferenceFromPreviousColumn =>
      '% difference from previous column',
    ValueDisplay.runningTotalRows => 'Running total along rows',
    ValueDisplay.runningTotalColumns => 'Running total along columns',
    ValueDisplay.rankRows => 'Rank along rows',
    ValueDisplay.rankColumns => 'Rank along columns',
  };

  @override
  String get formula => 'Formula';

  @override
  String get labelField => 'Label';

  @override
  String get countOfFacts => 'Count of records';

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

  @override
  String get filter => 'Filter';

  @override
  String get noFilter => 'No filter';

  @override
  String get addCondition => 'Add condition';

  @override
  String get addGroup => 'Add group';

  @override
  String get addExpression => 'Add expression';

  @override
  String get matchAll => 'All of the following';

  @override
  String get matchAny => 'Any of the following';

  @override
  String get negate => 'Not';

  @override
  String get opEquals => 'equals';

  @override
  String get opNotEquals => 'does not equal';

  @override
  String get opLess => 'is less than';

  @override
  String get opLessOrEqual => 'is at most';

  @override
  String get opGreater => 'is greater than';

  @override
  String get opGreaterOrEqual => 'is at least';

  @override
  String get opBetween => 'is between';

  @override
  String get opContains => 'contains';

  @override
  String get opStartsWith => 'starts with';

  @override
  String get opEndsWith => 'ends with';

  @override
  String get opIsEmpty => 'is empty';

  @override
  String get opIsNotEmpty => 'is not empty';

  @override
  String get opIsOneOf => 'is one of';

  @override
  String get opIsTrue => 'is true';

  @override
  String get opIsFalse => 'is false';

  @override
  String get customFilter => 'Custom filter';

  @override
  String get expression => 'Expression';

  @override
  String get selectValues => 'Select values…';

  @override
  String selectedCount(int count) => '$count selected';

  @override
  String get clear => 'Clear';

  @override
  String get apply => 'Apply';

  @override
  String get column => 'Column';

  @override
  String get value => 'Value';

  @override
  String exprTypeName(ExprType type) => switch (type) {
    ExprType.number => 'number',
    ExprType.text => 'text',
    ExprType.boolean => 'boolean',
    ExprType.date => 'date',
  };

  @override
  String expressionErrorText(ExpressionErrorKind kind, List<String> a) =>
      switch (kind) {
        ExpressionErrorKind.unexpectedCharacter =>
          'unexpected character "${a[0]}"',
        ExpressionErrorKind.unterminatedText => 'unterminated text literal',
        ExpressionErrorKind.unterminatedName => 'missing "]" after column name',
        ExpressionErrorKind.unterminatedDate => 'missing "#" after date',
        ExpressionErrorKind.invalidNumber => 'invalid number "${a[0]}"',
        ExpressionErrorKind.invalidDate => 'invalid date "${a[0]}"',
        ExpressionErrorKind.unexpectedToken => 'unexpected "${a[0]}"',
        ExpressionErrorKind.unexpectedEnd => 'unexpected end of expression',
        ExpressionErrorKind.unknownColumn => 'unknown column "${a[0]}"',
        ExpressionErrorKind.unknownFunction => 'unknown function "${a[0]}"',
        ExpressionErrorKind.argumentCount =>
          '${a[0]} expects ${a[1]} argument(s), got ${a[2]}',
        ExpressionErrorKind.argumentType =>
          'argument ${a[1]} of ${a[0]} must be ${a[2]}, not ${a[3]}',
        ExpressionErrorKind.operandType =>
          'operand of ${a[0]} must be ${a[1]}, not ${a[2]}',
        ExpressionErrorKind.incompatibleTypes =>
          'cannot apply ${a[0]} to ${a[1]} and ${a[2]}',
        ExpressionErrorKind.unknownType => 'cannot determine the type',
        ExpressionErrorKind.notAllowedHere => '"${a[0]}" is not allowed here',
        ExpressionErrorKind.resultType =>
          'the expression must be ${a[0]}, not ${a[1]}',
      };
}
