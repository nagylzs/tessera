import '../cube/aggregate.dart';
import '../cube/aggregate_kind.dart';
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

  /// Count of non-null values of [target].
  String countOf(String target);
  String distinctCountOf(String target);

  /// Label of the count-of-facts aggregate in headers, e.g. "count".
  String get countLabel;

  // ------------------------------------------------- aggregate functions

  /// Function names as shown in the aggregate picker.
  String get sum;
  String get average;
  String get minimum;
  String get maximum;
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
  String largeExpansion(String label, int added, {required bool isRow});

  // ------------------------------------------------ derived, concrete

  /// Label of an aggregate: built-in ones are composed from the column
  /// label with this locale's rules; custom ones use [Aggregate.labelFor].
  String aggregateLabel(Aggregate aggregate, FactTable facts) =>
      switch (aggregate) {
        SumAggregate(:final measure) => sumOf(measure.labelFor(facts)),
        AverageAggregate(:final measure) => averageOf(measure.labelFor(facts)),
        MinAggregate(:final measure) => minimumOf(measure.labelFor(facts)),
        MaxAggregate(:final measure) => maximumOf(measure.labelFor(facts)),
        CountNonNullAggregate(:final measure) => countOf(
          measure.labelFor(facts),
        ),
        DistinctCountAggregate(:final dimension) => distinctCountOf(
          dimensionLabel(dimension, facts),
        ),
        CountAggregate() => countLabel,
        _ => aggregate.labelFor(facts),
      };

  String aggregateKindLabel(AggregateKind kind) => switch (kind) {
    AggregateKind.sum => sum,
    AggregateKind.average => average,
    AggregateKind.min => minimum,
    AggregateKind.max => maximum,
    AggregateKind.countNonNull => countOfValues,
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
