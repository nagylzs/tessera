/// Compares two dimension values with `null` ordered first.
///
/// [Comparable] values compare naturally; [bool] orders `false < true`.
int compareDimensionValues(Object? a, Object? b) {
  if (a == null) return b == null ? 0 : -1;
  if (b == null) return 1;
  if (a is bool && b is bool) return (a ? 1 : 0) - (b ? 1 : 0);
  if (a is Comparable && b is Comparable) return Comparable.compare(a, b);
  return a.toString().compareTo(b.toString());
}

/// ISO 8601 week number of [date] (1–53). The week belongs to the year of
/// its Thursday, so 2024‑12‑30 is week 1 and 2021‑01‑03 is week 53.
int isoWeek(DateTime date) {
  final day = DateTime.utc(date.year, date.month, date.day);
  final thursday = day.add(Duration(days: DateTime.thursday - day.weekday));
  final jan1 = DateTime.utc(thursday.year, 1, 1);
  return thursday.difference(jan1).inDays ~/ 7 + 1;
}

/// A groupable attribute of the facts.
///
/// A dimension is *derived from* a column of the [FactTable]; it is not the
/// column itself. The plain case is [ColumnDimension], which groups by the
/// column's value. [DatePartDimension] and [MappedDimension] compute their
/// value from the column, so one `date` column can back several dimensions
/// (`date.year`, `date.month`) that may be placed on different cube axes.
///
/// Dimensions are value objects identified by [id]; two instances with the
/// same id are the same dimension.
sealed class Dimension {
  const Dimension();

  /// Unique identifier, e.g. `country` or `date.month`.
  String get id;

  /// Human readable name.
  String get label;

  /// Name of the [FactTable] column this dimension reads.
  String get sourceColumn;

  /// Computes the dimension value from the raw column value. `null` in means
  /// `null` out: a missing source value always lands in the empty group.
  Object? valueOf(Object? columnValue);

  /// Formats a dimension value for display. The empty group (`null`) is
  /// rendered by the widget, not here.
  String formatValue(Object? value) => value?.toString() ?? '';

  /// Natural ordering of the dimension's values, `null` first.
  int compareValues(Object? a, Object? b) => compareDimensionValues(a, b);

  @override
  bool operator ==(Object other) => other is Dimension && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Dimension($id)';
}

/// Groups by the column value as stored.
final class ColumnDimension extends Dimension {
  const ColumnDimension(this.sourceColumn, {this._label});

  @override
  final String sourceColumn;
  final String? _label;

  @override
  String get id => sourceColumn;

  @override
  String get label => _label ?? sourceColumn;

  @override
  Object? valueOf(Object? columnValue) => columnValue;
}

/// Calendar component extracted by a [DatePartDimension].
enum DatePart { year, quarter, month, week, day, weekday, hour }

/// Groups a date/dateTime column by one calendar component.
///
/// Values are [int]s (`month` = 1..12, `quarter` = 1..4, `weekday` = 1..7
/// with Monday = 1) so they sort chronologically; [formatValue] renders
/// month and weekday names.
final class DatePartDimension extends Dimension {
  const DatePartDimension(this.sourceColumn, this.part, {this._label});

  @override
  final String sourceColumn;
  final DatePart part;
  final String? _label;

  @override
  String get id => '$sourceColumn.${part.name}';

  @override
  String get label =>
      _label ?? '${sourceColumn.replaceAll('_', ' ')} ${part.name}';

  @override
  int? valueOf(Object? columnValue) {
    if (columnValue is! DateTime) return null;
    return switch (part) {
      DatePart.year => columnValue.year,
      DatePart.quarter => (columnValue.month - 1) ~/ 3 + 1,
      DatePart.month => columnValue.month,
      DatePart.week => isoWeek(columnValue),
      DatePart.day => columnValue.day,
      DatePart.weekday => columnValue.weekday,
      DatePart.hour => columnValue.hour,
    };
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
  String formatValue(Object? value) {
    if (value is! int) return '';
    return switch (part) {
      DatePart.month => _months[value - 1],
      DatePart.weekday => _weekdays[value - 1],
      DatePart.quarter => 'Q$value',
      _ => value.toString(),
    };
  }
}

/// Groups by an arbitrary function of the column value — buckets of a
/// numeric column, the first letter of a name, a lookup table, …
final class MappedDimension extends Dimension {
  const MappedDimension({
    required this.id,
    required this.sourceColumn,
    required this._map,
    this._label,
    this._compare,
    this._format,
  });

  @override
  final String id;
  @override
  final String sourceColumn;
  final String? _label;
  final Object? Function(Object?) _map;
  final int Function(Object?, Object?)? _compare;
  final String Function(Object?)? _format;

  @override
  String get label => _label ?? id;

  @override
  Object? valueOf(Object? columnValue) =>
      columnValue == null ? null : _map(columnValue);

  @override
  int compareValues(Object? a, Object? b) =>
      _compare?.call(a, b) ?? super.compareValues(a, b);

  @override
  String formatValue(Object? value) =>
      _format?.call(value) ?? super.formatValue(value);
}
