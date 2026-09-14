import '../expr/ast.dart';
import '../expr/checker.dart';
import '../expr/expr_type.dart';
import '../expr/expression.dart';
import '../expr/functions.dart';
import '../facts/dimension.dart';
import '../facts/fact_table.dart';

/// Restricts which facts a [Cube] sees, independently of its axes.
///
/// This is the "filter area" of a pivot table: `year = 2025` without `year`
/// appearing in a header. Filters compose with [AndFilter] / [OrFilter] /
/// [NotFilter].
///
/// Two families exist. The structured filters ([ValueFilter],
/// [CompareFilter], [RangeFilter], [TextFilter], [EmptyFilter]) are plain
/// data an editor can build and an application can store; each one can be
/// written as an expression ([toExpressionSource]). [ExpressionFilter]
/// holds an arbitrary boolean expression in the expression language; and
/// [PredicateFilter] wraps a Dart function, which cannot be stored.
sealed class FactFilter {
  const FactFilter();

  bool matches(FactTable facts, int row);

  /// A predicate bound to [facts], used by the engine to scan all rows.
  /// Expression-based filters compile once here; the default calls
  /// [matches].
  bool Function(int row) compile(FactTable facts) =>
      (row) => matches(facts, row);

  /// This filter as an expression of the expression language, or `null`
  /// when it cannot be written as one ([PredicateFilter], a [ValueFilter]
  /// over a [MappedDimension], or a combination containing such a filter).
  String? toExpressionSource();
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

  @override
  String? toExpressionSource() {
    final String subject;
    switch (dimension) {
      case ColumnDimension(:final sourceColumn):
        subject = Expr.quoteName(sourceColumn);
      case DatePartDimension(:final sourceColumn, :final part):
        subject = '${part.name}(${Expr.quoteName(sourceColumn)})';
      case ExpressionDimension(:final source):
        subject = '(${Expression.parse(source).canonicalSource})';
      case MappedDimension():
        return null;
    }
    final hasNull = values.contains(null);
    final rest = [
      for (final v in values)
        if (v != null) literalSource(v),
    ];
    final parts = [
      if (hasNull) '$subject is empty',
      if (rest.isNotEmpty) '$subject in (${rest.join(', ')})',
    ];
    if (parts.isEmpty) return 'false';
    return parts.length == 1 ? parts.single : '(${parts.join(' or ')})';
  }
}

/// Escape hatch for arbitrary conditions.
final class PredicateFilter extends FactFilter {
  const PredicateFilter(this.predicate, {this.label});

  final bool Function(FactTable facts, int row) predicate;
  final String? label;

  @override
  bool matches(FactTable facts, int row) => predicate(facts, row);

  @override
  String? toExpressionSource() => null;
}

final class AndFilter extends FactFilter {
  const AndFilter(this.filters);
  final List<FactFilter> filters;

  @override
  bool matches(FactTable facts, int row) =>
      filters.every((f) => f.matches(facts, row));

  @override
  bool Function(int row) compile(FactTable facts) {
    final fs = [for (final f in filters) f.compile(facts)];
    return (row) {
      for (final f in fs) {
        if (!f(row)) return false;
      }
      return true;
    };
  }

  @override
  String? toExpressionSource() => _join(filters, 'and', 'true');
}

final class OrFilter extends FactFilter {
  const OrFilter(this.filters);
  final List<FactFilter> filters;

  @override
  bool matches(FactTable facts, int row) =>
      filters.any((f) => f.matches(facts, row));

  @override
  bool Function(int row) compile(FactTable facts) {
    final fs = [for (final f in filters) f.compile(facts)];
    return (row) {
      for (final f in fs) {
        if (f(row)) return true;
      }
      return false;
    };
  }

  @override
  String? toExpressionSource() => _join(filters, 'or', 'false');
}

String? _join(List<FactFilter> filters, String op, String empty) {
  if (filters.isEmpty) return empty;
  final parts = <String>[];
  for (final f in filters) {
    final s = f.toExpressionSource();
    if (s == null) return null;
    parts.add(s);
  }
  return parts.length == 1 ? parts.single : '(${parts.join(' $op ')})';
}

final class NotFilter extends FactFilter {
  const NotFilter(this.filter);
  final FactFilter filter;

  @override
  bool matches(FactTable facts, int row) => !filter.matches(facts, row);

  @override
  bool Function(int row) compile(FactTable facts) {
    final f = filter.compile(facts);
    return (row) => !f(row);
  }

  @override
  String? toExpressionSource() {
    final s = filter.toExpressionSource();
    return s == null ? null : 'not $s';
  }
}

/// Keeps facts for which [source], a boolean expression over the columns
/// (`total > 100 and region = "Europe"`), is true; facts where it is
/// unknown (a missing value in a comparison) are excluded, as in SQL.
///
/// The expression is checked and compiled the first time the filter meets
/// a fact table; a parse or type error surfaces then as an
/// [ExpressionError]. Check beforehand with [Expression.validate] and
/// `ExpressionScope.ofFacts(facts)` (or `ofSchema`), `expected:
/// ExprType.boolean`. Two filters are equal when their sources are.
final class ExpressionFilter extends FactFilter {
  ExpressionFilter(this.source, {this.functions, this.label});

  final String source;

  /// Functions beyond the built-in ones the expression may call.
  final FunctionRegistry? functions;
  final String? label;

  FactTable? _boundFacts;
  bool Function(int)? _bound;

  @override
  bool Function(int row) compile(FactTable facts) {
    if (identical(facts, _boundFacts)) return _bound!;
    final compiled = Expression.parse(source)
        .compile(
          facts,
          scope: ExpressionScope.ofFacts(facts, functions: functions),
          expected: ExprType.boolean,
        )
        .asBoolean;
    _boundFacts = facts;
    return _bound = (row) => compiled(row) == true;
  }

  @override
  bool matches(FactTable facts, int row) => compile(facts)(row);

  @override
  String toExpressionSource() => source;

  @override
  bool operator ==(Object other) =>
      other is ExpressionFilter && other.source == source;

  @override
  int get hashCode => source.hashCode;

  @override
  String toString() => 'ExpressionFilter($source)';
}

/// How [CompareFilter] compares.
enum CompareOp {
  equal('='),
  notEqual('<>'),
  less('<'),
  lessOrEqual('<='),
  greater('>'),
  greaterOrEqual('>=');

  const CompareOp(this.symbol);
  final String symbol;
}

/// Base of the structured column filters: each is data that renders to an
/// expression, and matches through that expression.
sealed class ColumnFilter extends FactFilter {
  ColumnFilter(this.column);

  /// The fact table column the filter reads.
  final String column;

  late final ExpressionFilter _expression = ExpressionFilter(
    toExpressionSource(),
  );

  @override
  String toExpressionSource();

  @override
  bool Function(int row) compile(FactTable facts) => _expression.compile(facts);

  @override
  bool matches(FactTable facts, int row) => _expression.matches(facts, row);

  @override
  bool operator ==(Object other) =>
      other.runtimeType == runtimeType &&
      (other as ColumnFilter).toExpressionSource() == toExpressionSource();

  @override
  int get hashCode => toExpressionSource().hashCode;

  @override
  String toString() => '$runtimeType(${toExpressionSource()})';
}

/// `column op value`: keeps facts whose [column] compares as [op] says to
/// [value] (a `num`, `String`, `bool` or UTC `DateTime`). Facts with an
/// empty value never match.
final class CompareFilter extends ColumnFilter {
  CompareFilter(super.column, this.op, this.value);

  final CompareOp op;
  final Object value;

  @override
  String toExpressionSource() =>
      '${Expr.quoteName(column)} ${op.symbol} ${literalSource(value)}';
}

/// Keeps facts whose [column] is between [low] and [high], inclusive.
final class RangeFilter extends ColumnFilter {
  RangeFilter(super.column, this.low, this.high);

  final Object low;
  final Object high;

  @override
  String toExpressionSource() =>
      '${Expr.quoteName(column)} between ${literalSource(low)} and ${literalSource(high)}';
}

/// How [TextFilter] matches (case-sensitive).
enum TextMatch { contains, startsWith, endsWith }

/// Keeps facts whose text [column] contains / starts with / ends with
/// [text].
final class TextFilter extends ColumnFilter {
  TextFilter(super.column, this.match, this.text);

  final TextMatch match;
  final String text;

  @override
  String toExpressionSource() {
    final fn = switch (match) {
      TextMatch.contains => 'contains',
      TextMatch.startsWith => 'startswith',
      TextMatch.endsWith => 'endswith',
    };
    return '$fn(${Expr.quoteName(column)}, ${Expr.quoteText(text)})';
  }
}

/// Keeps facts whose [column] is empty (or, with [negated], not empty).
final class EmptyFilter extends ColumnFilter {
  EmptyFilter(super.column, {this.negated = false});

  final bool negated;

  @override
  String toExpressionSource() =>
      '${Expr.quoteName(column)} is ${negated ? 'not empty' : 'empty'}';
}

/// [value] as a literal of the expression language: numbers as written,
/// text in double quotes, `true` / `false`, dates as `#yyyy-MM-dd#`, `null`
/// for `null`.
String literalSource(Object? value) => switch (value) {
  null => 'null',
  num n => NumberLiteral(n.toDouble(), offset: 0, length: 0).toSource(),
  String s => Expr.quoteText(s),
  bool b => b ? 'true' : 'false',
  DateTime d => '#${DateLiteral.formatDate(d.isUtc ? d : d.toUtc())}#',
  _ => Expr.quoteText(value.toString()),
};
