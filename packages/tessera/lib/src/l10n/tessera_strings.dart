import '../cube/aggregate.dart';
import '../cube/aggregate_kind.dart';
import '../cube/layout_aggregate.dart';
import '../expr/expr_type.dart';
import '../expr/expression_error.dart';
import '../facts/dimension.dart';
import '../facts/fact_table.dart';
import 'locales.dart';

/// Every user-facing text of Tessera, plus the locale-specific rules for
/// composing labels ("sum of Revenue" vs "Revenue összege") and formatting
/// numbers and date parts.
///
/// Fourteen languages are built in (see [builtInStrings] and
/// [forLanguage]). This class has no Flutter dependency, so exporters and
/// server-side code can produce localized headers with the same rules the
/// widgets use; `package:tessera_flutter` adds the `LocalizationsDelegate`
/// and `of(context)` lookup on top of it.
///
/// Every member is abstract so a built-in locale can never be silently
/// incomplete. To add a language, extend this class (or extend
/// [TesseraStringsEn] and override just what differs).
abstract class TesseraStrings {
  const TesseraStrings();

  /// ISO 639-1 code, e.g. `en`.
  String get languageCode;

  // ---------------------------------------------------- aggregate labels

  /// "sum of Revenue".
  String sumOf(String target);
  String averageOf(String target);
  String minimumOf(String target);
  String maximumOf(String target);

  /// "std dev of Revenue" (sample) and the population, variance and
  /// population-variance twins.
  String stdDevOf(String target);
  String stdDevPopulationOf(String target);
  String varianceOf(String target);
  String variancePopulationOf(String target);

  /// Count of non-null values of [target].
  String countOf(String target);
  String distinctCountOf(String target);

  /// Label of the count-of-facts aggregate in headers, e.g. "count".
  String get countLabel;

  // ------------------------------------------ layout-relative labels

  /// "sum of Revenue % of row total": [base] is the label of the aggregate
  /// the calculation is applied to.
  String percentOfTotal(String base, TotalOf of);

  /// "sum of Revenue difference from previous" ([percent] = false) or
  /// "… % difference from previous" ([percent] = true); [item] is
  /// [previousItem], [nextItem] or a group value as text.
  String differenceFrom(String base, String item, {required bool percent});

  /// The reference items of [differenceFrom].
  String get previousItem;
  String get nextItem;

  /// "sum of Revenue running total".
  String runningTotalOf(String base);

  /// "sum of Revenue rank".
  String rankOf(String base);

  /// The "show values as" menu of an aggregate and the names of its
  /// choices ("Plain value", "% of row total", …).
  String get showValuesAs;
  String valueDisplayName(ValueDisplay display);

  /// The aggregate picker's cell-formula function and the caption of the
  /// label field next to an expression.
  String get formula;
  String get labelField;

  // ------------------------------------------------- aggregate functions

  /// Function names as shown in the aggregate picker.
  String get sum;
  String get average;
  String get minimum;
  String get maximum;
  String get standardDeviation;
  String get populationStandardDeviation;
  String get variance;
  String get populationVariance;
  String get countOfValues;
  String get distinctCount;

  /// Function name of the count-of-facts aggregate in the picker.
  String get countOfFacts;

  // ---------------------------------------------------------------- dates

  String datePartName(DatePart part);

  /// Label of a date-part dimension, e.g. "date year" / "dátum év".
  String datePartLabel(String column, DatePart part);

  /// 1 = January.
  String monthName(int month);

  /// 1 = Monday, 7 = Sunday.
  String weekdayName(int weekday);

  /// Short quarter label, e.g. "Q1".
  String quarter(int quarter);

  // -------------------------------------------------------------- numbers

  String get decimalSeparator;
  String get groupSeparator;

  // ------------------------------------------------------- widget chrome

  String get rows;
  String get columns;
  String get values;

  /// Header of the group of facts lacking a value.
  String get emptyGroup;

  /// Header of the summary row/column.
  String get total;
  String get dropDimensionsHere;
  String get addDimension;
  String get addAggregate;
  String get search;
  String get alreadyInUse;
  String get function;
  String get expand;
  String get largeExpansionTitle;

  /// Items of the dimension-title menu of the grid.
  String get sortAscending;
  String get sortDescending;

  /// Menu item that clears a level's own sort so it inherits the level
  /// above (see `AxisDimension.sort`).
  String get inheritSort;

  /// Where an axis puts its summary (`CubeAxis.summaryPosition`), as
  /// offered by the axis editor's caption menu.
  String get totalsAtEnd;
  String get totalsAtStart;
  String get totalsHidden;

  /// Where an expanded group's own row goes (`CubeAxis.subtotalPosition`
  /// on the row axis) …
  String get subtotalsAbove;
  String get subtotalsBelow;

  /// … and its own column on the column axis.
  String get subtotalsLeft;
  String get subtotalsRight;
  String get subtotalsHidden;
  String get expandAll;
  String get collapseAll;
  String largeExpansion(String label, int added, {required bool isRow});

  // ------------------------------------------------------ filter editor

  /// Title and tooltip of the filter editor.
  String get filter;
  String get noFilter;
  String get addCondition;
  String get addGroup;
  String get addExpression;

  /// The two ways a group combines its conditions.
  String get matchAll;
  String get matchAny;

  /// The toggle that negates a group.
  String get negate;

  /// Operators of a condition row.
  String get opEquals;
  String get opNotEquals;
  String get opLess;
  String get opLessOrEqual;
  String get opGreater;
  String get opGreaterOrEqual;
  String get opBetween;
  String get opContains;
  String get opStartsWith;
  String get opEndsWith;
  String get opIsEmpty;
  String get opIsNotEmpty;
  String get opIsOneOf;
  String get opIsTrue;
  String get opIsFalse;

  /// A filter the editor can only show and remove (a Dart predicate).
  String get customFilter;
  String get expression;
  String get selectValues;
  String selectedCount(int count);
  String get clear;
  String get apply;
  String get column;
  String get value;

  // --------------------------------------------------- expression errors

  /// The name of an expression type in error messages.
  String exprTypeName(ExprType type);

  /// The message for an expression error of [kind]; [arguments] as in
  /// [ExpressionError.arguments], with type names already localized.
  String expressionErrorText(ExpressionErrorKind kind, List<String> arguments);

  /// The localized message of [error] (see [ExpressionError.message] for
  /// the English one).
  String expressionError(ExpressionError error) => expressionErrorText(
    error.kind,
    [for (final a in error.arguments) _typeArgument(a)],
  );

  String _typeArgument(String argument) {
    for (final t in ExprType.values) {
      if (t.name == argument) return exprTypeName(t);
    }
    return argument;
  }

  // ------------------------------------------------ derived, concrete

  /// Label of an aggregate: built-in ones are composed from the column
  /// label with this locale's rules; custom ones use [Aggregate.labelFor].
  String aggregateLabel(
    Aggregate aggregate,
    FactTable facts,
  ) => switch (aggregate) {
    SumAggregate(:final measure) => sumOf(measure.labelFor(facts)),
    AverageAggregate(:final measure) => averageOf(measure.labelFor(facts)),
    MinAggregate(:final measure) => minimumOf(measure.labelFor(facts)),
    MaxAggregate(:final measure) => maximumOf(measure.labelFor(facts)),
    StdDevAggregate(:final measure) => stdDevOf(measure.labelFor(facts)),
    StdDevPopulationAggregate(:final measure) => stdDevPopulationOf(
      measure.labelFor(facts),
    ),
    VarianceAggregate(:final measure) => varianceOf(measure.labelFor(facts)),
    VariancePopulationAggregate(:final measure) => variancePopulationOf(
      measure.labelFor(facts),
    ),
    CountNonNullAggregate(:final measure) => countOf(measure.labelFor(facts)),
    DistinctCountAggregate(:final dimension) => distinctCountOf(
      dimensionLabel(dimension, facts),
    ),
    CountAggregate() => countLabel,
    PercentOfTotalAggregate(:final base, :final of) => percentOfTotal(
      aggregateLabel(base, facts),
      of,
    ),
    DifferenceFromAggregate(:final base, :final item) => differenceFrom(
      aggregateLabel(base, facts),
      _itemLabel(item),
      percent: false,
    ),
    PercentDifferenceFromAggregate(:final base, :final item) => differenceFrom(
      aggregateLabel(base, facts),
      _itemLabel(item),
      percent: true,
    ),
    RunningTotalAggregate(:final base) => runningTotalOf(
      aggregateLabel(base, facts),
    ),
    RankAggregate(:final base) => rankOf(aggregateLabel(base, facts)),
    _ => aggregate.labelFor(facts),
  };

  String _itemLabel(BaseItem item) => switch (item) {
    PreviousItem() => previousItem,
    NextItem() => nextItem,
    ValueItem(:final value) => value == null ? emptyGroup : value.toString(),
  };

  String aggregateKindLabel(AggregateKind kind) => switch (kind) {
    AggregateKind.sum => sum,
    AggregateKind.average => average,
    AggregateKind.min => minimum,
    AggregateKind.max => maximum,
    AggregateKind.countNonNull => countOfValues,
    AggregateKind.stdDev => standardDeviation,
    AggregateKind.stdDevPopulation => populationStandardDeviation,
    AggregateKind.variance => variance,
    AggregateKind.variancePopulation => populationVariance,
    AggregateKind.distinctCount => distinctCount,
    AggregateKind.count => countOfFacts,
  };

  /// Label of a dimension: an explicit label wins; date parts are composed
  /// with [datePartLabel]; otherwise [Dimension.labelFor].
  String dimensionLabel(Dimension dimension, FactTable facts) {
    if (dimension is DatePartDimension && dimension.explicitLabel == null) {
      final column =
          facts.findColumn(dimension.sourceColumn)?.label ??
          dimension.sourceColumn;
      return datePartLabel(column, dimension.part);
    }
    return dimension.labelFor(facts);
  }

  /// A group's header text: month, weekday and quarter names for date
  /// parts, otherwise [Dimension.formatValue]. Empty for `null`.
  String formatValue(Dimension? dimension, Object? value) {
    if (value == null || dimension == null) return '';
    if (dimension is DatePartDimension &&
        dimension.explicitLabel == null &&
        value is int) {
      return switch (dimension.part) {
        DatePart.month => monthName(value),
        DatePart.weekday => weekdayName(value),
        DatePart.quarter => quarter(value),
        _ => value.toString(),
      };
    }
    return dimension.formatValue(value);
  }

  /// Integers as-is, other numbers with two decimals; digits grouped with
  /// [groupSeparator], [decimalSeparator] for the fraction.
  String formatNumber(num value) {
    final isInteger =
        value is int ||
        (value == value.truncateToDouble() && value.abs() < 1e15);
    final text = isInteger
        ? value.toInt().abs().toString()
        : value.abs().toStringAsFixed(2);
    final dot = text.indexOf('.');
    final intPart = dot < 0 ? text : text.substring(0, dot);
    final grouped = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) grouped.write(groupSeparator);
      grouped.write(intPart[i]);
    }
    final sign = value < 0 ? '-' : '';
    return dot < 0
        ? '$sign$grouped'
        : '$sign$grouped$decimalSeparator${text.substring(dot + 1)}';
  }

  // --------------------------------------------------------------- lookup

  /// The built-in strings for a language code, or `null`.
  static TesseraStrings? forLanguage(String languageCode) =>
      builtInStrings[languageCode];

  /// Language codes with built-in strings, in the order of [builtInStrings].
  static List<String> get supportedLanguages =>
      List.unmodifiable(builtInStrings.keys);
}
