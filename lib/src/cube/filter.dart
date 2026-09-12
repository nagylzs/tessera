import '../facts/dimension.dart';
import '../facts/fact_table.dart';

/// Restricts which facts a [Cube] sees, independently of its axes.
///
/// This is the "filter area" of a pivot table: `year = 2025` without `year`
/// appearing in a header. Filters compose with [AndFilter] / [OrFilter] /
/// [NotFilter].
sealed class FactFilter {
  const FactFilter();

  bool matches(FactTable facts, int row);
}

/// Keeps facts whose [dimension] value is one of [values] (`null` allowed,
/// meaning the empty group).
final class ValueFilter extends FactFilter {
  ValueFilter(this.dimension, Iterable<Object?> values)
    : values = Set.unmodifiable(values);

  final Dimension dimension;
  final Set<Object?> values;

  @override
  bool matches(FactTable facts, int row) =>
      values.contains(facts.dimensionValue(row, dimension));
}

/// Escape hatch for arbitrary conditions.
final class PredicateFilter extends FactFilter {
  const PredicateFilter(this.predicate, {this.label});

  final bool Function(FactTable facts, int row) predicate;
  final String? label;

  @override
  bool matches(FactTable facts, int row) => predicate(facts, row);
}

final class AndFilter extends FactFilter {
  const AndFilter(this.filters);
  final List<FactFilter> filters;

  @override
  bool matches(FactTable facts, int row) =>
      filters.every((f) => f.matches(facts, row));
}

final class OrFilter extends FactFilter {
  const OrFilter(this.filters);
  final List<FactFilter> filters;

  @override
  bool matches(FactTable facts, int row) =>
      filters.any((f) => f.matches(facts, row));
}

final class NotFilter extends FactFilter {
  const NotFilter(this.filter);
  final FactFilter filter;

  @override
  bool matches(FactTable facts, int row) => !filter.matches(facts, row);
}
