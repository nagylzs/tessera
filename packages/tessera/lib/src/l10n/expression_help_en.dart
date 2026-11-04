import 'expression_help.dart';

/// en texts of the expression help.
final class ExpressionHelpStringsEn extends ExpressionHelpStrings {
  const ExpressionHelpStringsEn();

  @override
  String get languageCode => 'en';

  @override
  String get title => 'Expression help';

  @override
  String get tapToInsert =>
      'Tap an example, a column or a function to insert it.';

  @override
  String intro(ExpressionHelpUse use) => switch (use) {
    ExpressionHelpUse.filter =>
      'A filter keeps the rows for which the expression is true. '
          'Combine conditions with and, or and not.',
    ExpressionHelpUse.measure =>
      'A calculated measure is worked out for every row from its columns, '
          'then summed or averaged like a column.',
    ExpressionHelpUse.dimension =>
      'A computed dimension groups the rows by the value of the '
          'expression, as a column would: a number, a text, a date or '
          'true/false.',
    ExpressionHelpUse.formula =>
      'A cell formula is calculated in every cell of the pivot from the '
          "cell's aggregates, such as sum(x) or count.",
  };

  @override
  String get examples => 'Examples';

  @override
  String get columns => 'Columns';

  @override
  String get aggregates => 'Aggregates';

  @override
  String get operators => 'Operators';

  @override
  String get values => 'Values';

  @override
  String get rules => 'Rules';

  @override
  String get functions => 'Functions';

  @override
  String get aggregateArgument =>
      'x is a column or a calculation over the columns of a row: '
      'sum(quantity * price). count alone counts the rows.';

  @override
  String groupName(ExpressionHelpGroup group) => switch (group) {
    ExpressionHelpGroup.conditional => 'Conditions',
    ExpressionHelpGroup.numbers => 'Numbers',
    ExpressionHelpGroup.text => 'Text',
    ExpressionHelpGroup.dates => 'Dates',
    ExpressionHelpGroup.other => 'Other functions',
  };

  @override
  String operatorText(ExpressionHelpOperator operator) => switch (operator) {
    ExpressionHelpOperator.arithmetic =>
      'Add, subtract, multiply, divide. Dividing by zero gives an empty '
          'value.',
    ExpressionHelpOperator.remainder =>
      'The remainder of a division: 7 % 3 is 1.',
    ExpressionHelpOperator.comparison =>
      'Equal, not equal, less, less or equal, greater, greater or equal. '
          '== and != work too.',
    ExpressionHelpOperator.logic =>
      'Both conditions, either of them, the opposite.',
    ExpressionHelpOperator.inList =>
      'x is one of the values listed, or none of them.',
    ExpressionHelpOperator.between => 'a ≤ x ≤ b, both ends included.',
    ExpressionHelpOperator.emptyTest => 'x has no value, or has one.',
    ExpressionHelpOperator.dates =>
      'n days after or before a date; the days between two dates.',
  };

  @override
  String literalText(ExpressionHelpLiteral literal) => switch (literal) {
    ExpressionHelpLiteral.number =>
      'Numbers, always with a decimal point: 12.5, not 12,5.',
    ExpressionHelpLiteral.text =>
      'Text in double or single quotes. A quote inside is doubled: '
          '"say ""hi""".',
    ExpressionHelpLiteral.date =>
      'Dates, with a time if needed, between # signs, the year first.',
    ExpressionHelpLiteral.boolean => 'Logical values.',
    ExpressionHelpLiteral.empty => 'The empty value.',
    ExpressionHelpLiteral.name =>
      'A column name with spaces or punctuation, or one spelt like a '
          'keyword, goes in square brackets.',
  };

  @override
  String ruleText(ExpressionHelpRule rule) => switch (rule) {
    ExpressionHelpRule.emptyValues =>
      'A calculation or comparison with an empty value is empty: '
          'price * 2 and price > 0 are empty where the price is. '
          'coalesce(price, 0) uses 0 instead; price is empty finds the '
          'rows without a price.',
    ExpressionHelpRule.filters =>
      'A filter keeps a row only where its expression is true: '
          'discount > 0 drops the rows without a discount, '
          'discount > 0 or discount is empty keeps them.',
    ExpressionHelpRule.letterCase =>
      'Function names and keywords may be written in any case (YEAR, '
          'Year); column names must match exactly. Text comparisons are '
          'case-sensitive: compare lower(x) to ignore case.',
  };

  @override
  ({String signature, String description}) function(
    ExpressionHelpFunction function,
  ) => switch (function) {
    ExpressionHelpFunction.ifElse => (
      signature: 'if(condition, a, b)',
      description:
          'a where the condition is true, otherwise b (also where the '
          'condition is empty). a and b are of the same type.',
    ),
    ExpressionHelpFunction.coalesce => (
      signature: 'coalesce(a, b, …)',
      description: 'The first of its arguments that is not empty.',
    ),
    ExpressionHelpFunction.isempty => (
      signature: 'isempty(x)',
      description: 'True where x is empty, the same as x is empty.',
    ),
    ExpressionHelpFunction.abs => (
      signature: 'abs(x)',
      description: 'x without its sign.',
    ),
    ExpressionHelpFunction.round => (
      signature: 'round(x, digits)',
      description:
          'x rounded to digits decimal places, to a whole number without '
          'digits. A negative digits rounds to tens, hundreds…: '
          'round(1234.5, -2) is 1200.',
    ),
    ExpressionHelpFunction.floor => (
      signature: 'floor(x)',
      description:
          'x rounded down to a whole number: floor(2.7) is 2, '
          'floor(-2.5) is -3.',
    ),
    ExpressionHelpFunction.ceil => (
      signature: 'ceil(x)',
      description: 'x rounded up to a whole number: ceil(2.1) is 3.',
    ),
    ExpressionHelpFunction.sqrt => (
      signature: 'sqrt(x)',
      description: 'The square root of x; empty for a negative x.',
    ),
    ExpressionHelpFunction.min => (
      signature: 'min(x, y, …)',
      description: 'The smallest of the numbers, leaving out empty ones.',
    ),
    ExpressionHelpFunction.max => (
      signature: 'max(x, y, …)',
      description: 'The largest of the numbers, leaving out empty ones.',
    ),
    ExpressionHelpFunction.number => (
      signature: 'number(text)',
      description:
          'The number written in a text, with a decimal point; empty if '
          'the text is not a number.',
    ),
    ExpressionHelpFunction.len => (
      signature: 'len(text)',
      description: 'The number of characters in the text.',
    ),
    ExpressionHelpFunction.lower => (
      signature: 'lower(text)',
      description: 'The text in lower case.',
    ),
    ExpressionHelpFunction.upper => (
      signature: 'upper(text)',
      description: 'The text in upper case.',
    ),
    ExpressionHelpFunction.trim => (
      signature: 'trim(text)',
      description: 'The text without spaces at its start and end.',
    ),
    ExpressionHelpFunction.left => (
      signature: 'left(text, n)',
      description: 'The first n characters of the text.',
    ),
    ExpressionHelpFunction.right => (
      signature: 'right(text, n)',
      description: 'The last n characters of the text.',
    ),
    ExpressionHelpFunction.substring => (
      signature: 'substring(text, start, length)',
      description:
          'length characters of the text from position start, the first '
          'character being 1; without length, the rest of the text.',
    ),
    ExpressionHelpFunction.contains => (
      signature: 'contains(text, part)',
      description: 'True where part occurs in the text.',
    ),
    ExpressionHelpFunction.startswith => (
      signature: 'startswith(text, part)',
      description: 'True where the text begins with part.',
    ),
    ExpressionHelpFunction.endswith => (
      signature: 'endswith(text, part)',
      description: 'True where the text ends with part.',
    ),
    ExpressionHelpFunction.replace => (
      signature: 'replace(text, old, new)',
      description: 'The text with every old replaced by new.',
    ),
    ExpressionHelpFunction.concat => (
      signature: 'concat(a, b, …)',
      description:
          'The texts joined, leaving out empty ones. text(x) turns a '
          'number or a date into text.',
    ),
    ExpressionHelpFunction.text => (
      signature: 'text(x)',
      description:
          'A number, a date or true/false as text: text(1.5) is "1.5", '
          'text(#2024-01-31#) is "2024-01-31".',
    ),
    ExpressionHelpFunction.year => (
      signature: 'year(date)',
      description: 'The year of the date.',
    ),
    ExpressionHelpFunction.quarter => (
      signature: 'quarter(date)',
      description: 'The quarter of the year, 1 to 4.',
    ),
    ExpressionHelpFunction.month => (
      signature: 'month(date)',
      description: 'The month, 1 to 12.',
    ),
    ExpressionHelpFunction.week => (
      signature: 'week(date)',
      description: 'The ISO week number, 1 to 53.',
    ),
    ExpressionHelpFunction.day => (
      signature: 'day(date)',
      description: 'The day of the month, 1 to 31.',
    ),
    ExpressionHelpFunction.weekday => (
      signature: 'weekday(date)',
      description: 'The day of the week, 1 (Monday) to 7 (Sunday).',
    ),
    ExpressionHelpFunction.hour => (
      signature: 'hour(date)',
      description: 'The hour of the time, 0 to 23.',
    ),
    ExpressionHelpFunction.dateOfText => (
      signature: 'date(text)',
      description:
          'The date written in a text, year first: date("2024-01-31"); '
          'empty if the text is not a date.',
    ),
    ExpressionHelpFunction.dateOfParts => (
      signature: 'date(year, month, day)',
      description: 'The date of the year, month and day given.',
    ),
    ExpressionHelpFunction.today => (
      signature: 'today()',
      description: "Today's date.",
    ),
  };
}
