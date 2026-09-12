/// A numeric attribute of the facts that aggregates are computed from.
///
/// A measure refers to a numeric column of the [FactTable]. Which columns are
/// measures is a matter of use, not of the schema: the same `quantity`
/// column can be summed as a measure and grouped by as a [Dimension].
final class Measure {
  const Measure(this.column, {this._label});

  /// Name of the [FactTable] column, which must have a numeric [ColumnType].
  final String column;
  final String? _label;

  String get id => column;

  String get label => _label ?? column;

  @override
  bool operator ==(Object other) => other is Measure && other.column == column;

  @override
  int get hashCode => column.hashCode;

  @override
  String toString() => 'Measure($column)';
}
