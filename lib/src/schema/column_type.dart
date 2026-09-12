/// The data type of a column in a [Schema].
///
/// Values are stored in the [FactTable] as the Dart type given for each
/// member. Anything that cannot be parsed into the column's type is either
/// widened or nullified during import, depending on the
/// [TypeMismatchPolicy].
enum ColumnType {
  /// Free text, stored as [String]. The fallback when nothing more specific
  /// applies.
  text,

  /// Whole numbers, stored as [int].
  integer,

  /// Real numbers, stored as [double].
  number,

  /// `true` / `false`, stored as [bool].
  boolean,

  /// A calendar day without a time component, stored as a UTC-midnight
  /// [DateTime].
  date,

  /// A point in time, stored as [DateTime].
  dateTime;

  /// Whether values of this type can be used as a [Measure].
  bool get isNumeric => this == integer || this == number;

  /// Whether every value of this type can be represented as [other] without
  /// loss. Used by the importer's `widen` policy:
  /// `integer → number → text`, `date → dateTime → text`, `boolean → text`.
  bool canWidenTo(ColumnType other) {
    if (other == this || other == text) return true;
    return switch (this) {
      integer => other == number,
      date => other == dateTime,
      _ => false,
    };
  }
}
