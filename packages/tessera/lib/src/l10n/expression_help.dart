import '../cube/aggregate_kind.dart';
import '../expr/checker.dart';
import '../expr/expr_type.dart';
import 'tessera_strings.dart';

/// What an expression is for, which decides the introduction and the
/// examples of the expression help.
enum ExpressionHelpUse {
  /// A filter: a row expression that must be boolean.
  filter,

  /// A calculated measure: a row expression that must be a number.
  measure,

  /// A computed dimension: a row expression of any type.
  dimension,

  /// A cell formula: an expression over aggregates, in a cell scope.
  formula;

  /// The use of an expression checked in [scope] as [expected].
  static ExpressionHelpUse of(ExpressionScope scope, ExprType? expected) =>
      scope.isCellScope
      ? formula
      : switch (expected) {
          ExprType.boolean => filter,
          ExprType.number => measure,
          _ => dimension,
        };
}

/// The groups the expression help lists the functions in; [other] holds
/// the functions an application adds.
enum ExpressionHelpGroup { conditional, numbers, text, dates, other }

/// The built-in functions as the expression help lists them: one entry
/// per form, so `date(text)` and `date(year, month, day)` are two.
enum ExpressionHelpFunction {
  ifElse('if', ExpressionHelpGroup.conditional),
  coalesce('coalesce', ExpressionHelpGroup.conditional),
  isempty('isempty', ExpressionHelpGroup.conditional),
  abs('abs', ExpressionHelpGroup.numbers),
  round('round', ExpressionHelpGroup.numbers),
  floor('floor', ExpressionHelpGroup.numbers),
  ceil('ceil', ExpressionHelpGroup.numbers),
  sqrt('sqrt', ExpressionHelpGroup.numbers),
  min('min', ExpressionHelpGroup.numbers),
  max('max', ExpressionHelpGroup.numbers),
  number('number', ExpressionHelpGroup.numbers),
  len('len', ExpressionHelpGroup.text),
  lower('lower', ExpressionHelpGroup.text),
  upper('upper', ExpressionHelpGroup.text),
  trim('trim', ExpressionHelpGroup.text),
  left('left', ExpressionHelpGroup.text),
  right('right', ExpressionHelpGroup.text),
  substring('substring', ExpressionHelpGroup.text),
  contains('contains', ExpressionHelpGroup.text),
  startswith('startswith', ExpressionHelpGroup.text),
  endswith('endswith', ExpressionHelpGroup.text),
  replace('replace', ExpressionHelpGroup.text),
  concat('concat', ExpressionHelpGroup.text),
  text('text', ExpressionHelpGroup.text),
  year('year', ExpressionHelpGroup.dates),
  quarter('quarter', ExpressionHelpGroup.dates),
  month('month', ExpressionHelpGroup.dates),
  week('week', ExpressionHelpGroup.dates),
  day('day', ExpressionHelpGroup.dates),
  weekday('weekday', ExpressionHelpGroup.dates),
  hour('hour', ExpressionHelpGroup.dates),
  dateOfText('date', ExpressionHelpGroup.dates),
  dateOfParts('date', ExpressionHelpGroup.dates),
  today('today', ExpressionHelpGroup.dates, hasParameters: false);

  const ExpressionHelpFunction(
    this.functionName,
    this.group, {
    this.hasParameters = true,
  });

  /// The name as written in expressions.
  final String functionName;
  final ExpressionHelpGroup group;

  /// Whether the call takes arguments: `today()` does not.
  final bool hasParameters;
}

/// The aggregates a cell formula may name; their argument is a column or
/// a row expression, `count` alone counts the facts.
enum ExpressionHelpAggregate {
  sum('sum', AggregateKind.sum),
  avg('avg', AggregateKind.average),
  min('min', AggregateKind.min),
  max('max', AggregateKind.max),
  count('count', AggregateKind.count, hasParameters: false),
  countValues('count', AggregateKind.countNonNull),
  distinct('distinct', AggregateKind.distinctCount),
  stdev('stdev', AggregateKind.stdDev),
  stdevp('stdevp', AggregateKind.stdDevPopulation),
  variance('var', AggregateKind.variance),
  variancePopulation('varp', AggregateKind.variancePopulation);

  const ExpressionHelpAggregate(
    this.functionName,
    this.kind, {
    this.hasParameters = true,
  });

  final String functionName;

  /// The kind whose name ([TesseraStrings.aggregateKindLabel]) says
  /// what the aggregate is.
  final AggregateKind kind;
  final bool hasParameters;

  /// `sum(x)`, or `count` for the facts.
  String get syntax => hasParameters ? '$functionName(x)' : functionName;
}

/// The operators of the expression language as the help lists them,
/// with their [syntax] (the same in every language).
enum ExpressionHelpOperator {
  arithmetic('+   -   *   /'),
  remainder('%'),
  comparison('=   <>   <   <=   >   >='),
  logic('and   or   not'),
  inList('x in (a, b, …)   x not in (a, b, …)'),
  between('x between a and b'),
  emptyTest('x is empty   x is not empty'),
  dates('date + n   date - n   date - date');

  const ExpressionHelpOperator(this.syntax);

  final String syntax;
}

/// How values are written, with their [syntax] (the same in every
/// language).
enum ExpressionHelpLiteral {
  number('12.5   -3   2e6'),
  text('"text"   \'text\''),
  date('#2024-01-31#   #2024-01-31 14:30#'),
  boolean('true   false'),
  empty('null'),
  name('[unit price]   [and]');

  const ExpressionHelpLiteral(this.syntax);

  final String syntax;
}

/// The rules the expression help spells out.
enum ExpressionHelpRule { emptyValues, filters, letterCase }

/// The texts of the expression help (`showExpressionHelp` in
/// `tessera_flutter`): a reference to the expression language for people
/// who write an expression in an app. Reached through
/// [TesseraStrings.expressionHelp].
///
/// Every member is abstract and the enums are switched over
/// exhaustively, so a built-in locale can never be silently incomplete.
abstract class ExpressionHelpStrings {
  const ExpressionHelpStrings();

  /// ISO 639-1 code, e.g. `en`; the same as the [TesseraStrings] that
  /// return these.
  String get languageCode;

  /// The help's title and the tooltip of the button that opens it.
  String get title;

  /// The line under the title when the entries can be tapped.
  String get tapToInsert;

  /// A sentence or two on what an expression of [use] does.
  String intro(ExpressionHelpUse use);

  /// Section headings.
  String get examples;
  String get columns;
  String get aggregates;
  String get operators;
  String get values;
  String get rules;
  String get functions;

  /// Under the aggregates of a cell formula: what `x` stands for.
  String get aggregateArgument;

  String groupName(ExpressionHelpGroup group);
  String operatorText(ExpressionHelpOperator operator);
  String literalText(ExpressionHelpLiteral literal);
  String ruleText(ExpressionHelpRule rule);

  /// [function] as the help shows it, its parameters named in this
  /// language (`round(x, digits)`), and what it gives.
  ({String signature, String description}) function(
    ExpressionHelpFunction function,
  );
}
