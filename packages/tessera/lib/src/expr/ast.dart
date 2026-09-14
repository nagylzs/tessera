/// Syntax tree of an expression, as produced by `Expression.parse`.
///
/// Every node records the source range it came from ([offset], [length]) so
/// errors and editors can point at it. Nodes are immutable and compare by
/// identity; [toSource] renders the tree back to text in canonical form.
library;

/// The operators the grammar has, with their binding strength. Higher binds
/// tighter.
enum ExprPrecedence {
  or(1),
  and(2),
  not(3),
  comparison(4),
  additive(5),
  multiplicative(6),
  unary(7),
  primary(8);

  const ExprPrecedence(this.level);
  final int level;
}

/// The keywords of the grammar; column names equal to one must be quoted
/// (`[and]`).
const expressionKeywords = {
  'and',
  'or',
  'not',
  'in',
  'between',
  'is',
  'empty',
  'null',
  'true',
  'false',
};

sealed class Expr {
  const Expr({required this.offset, required this.length});

  /// Start of the node's text in the source, in UTF-16 code units.
  final int offset;

  /// Length of the node's text.
  final int length;

  int get end => offset + length;

  ExprPrecedence get precedence => ExprPrecedence.primary;

  /// The expression as canonical source text: keywords in lower case,
  /// minimal parentheses, column names quoted only when needed.
  String toSource();

  @override
  String toString() => toSource();

  /// [child] rendered with parentheses when it binds looser than [parent].
  static String wrap(Expr child, ExprPrecedence parent, {bool strict = false}) {
    final c = child.precedence.level, p = parent.level;
    final needs = strict ? c <= p : c < p;
    return needs ? '(${child.toSource()})' : child.toSource();
  }

  static final _bareName = RegExp(r'^[\p{L}_][\p{L}\p{N}_]*$', unicode: true);

  /// [name] as it appears in source: bare when it is a plain identifier and
  /// not a keyword, otherwise `[name]` with `]` doubled.
  static String quoteName(String name) =>
      _bareName.hasMatch(name) &&
          !expressionKeywords.contains(name.toLowerCase())
      ? name
      : '[${name.replaceAll(']', ']]')}]';

  /// [text] as a literal: double quotes, inner double quotes doubled.
  static String quoteText(String text) => '"${text.replaceAll('"', '""')}"';
}

final class NumberLiteral extends Expr {
  const NumberLiteral(
    this.value, {
    required super.offset,
    required super.length,
  });

  final double value;

  @override
  String toSource() {
    if (value.isNaN || value.isInfinite) return value.toString();
    return value == value.truncateToDouble() && value.abs() < 1e15
        ? value.toInt().toString()
        : value.toString();
  }
}

final class TextLiteral extends Expr {
  const TextLiteral(this.value, {required super.offset, required super.length});

  final String value;

  @override
  String toSource() => Expr.quoteText(value);
}

final class BooleanLiteral extends Expr {
  const BooleanLiteral(
    this.value, {
    required super.offset,
    required super.length,
  });

  final bool value;

  @override
  String toSource() => value ? 'true' : 'false';
}

/// A `#2024-01-31#` or `#2024-01-31 10:30:00#` literal; the value is UTC.
final class DateLiteral extends Expr {
  const DateLiteral(this.value, {required super.offset, required super.length});

  final DateTime value;

  @override
  String toSource() => '#${formatDate(value)}#';

  /// `yyyy-MM-dd`, with ` HH:mm:ss` when there is a time of day (and
  /// `.SSS` when there are milliseconds).
  static String formatDate(DateTime d) {
    String two(int n) => n < 10 ? '0$n' : '$n';
    final day =
        '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';
    if (d.hour == 0 && d.minute == 0 && d.second == 0 && d.millisecond == 0) {
      return day;
    }
    final time = '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
    return d.millisecond == 0
        ? '$day $time'
        : '$day $time.${d.millisecond.toString().padLeft(3, '0')}';
  }
}

/// The `null` keyword: a missing value of any type.
final class NullLiteral extends Expr {
  const NullLiteral({required super.offset, required super.length});

  @override
  String toSource() => 'null';
}

/// A bare or `[quoted]` name: a column in a row expression, or an
/// aggregate such as `count` in a cell formula.
final class NameRef extends Expr {
  const NameRef(this.name, {required super.offset, required super.length});

  final String name;

  @override
  String toSource() => Expr.quoteName(name);
}

enum UnaryOp {
  negate('-', ExprPrecedence.unary),
  not('not', ExprPrecedence.not);

  const UnaryOp(this.symbol, this.precedence);
  final String symbol;
  final ExprPrecedence precedence;
}

final class UnaryExpr extends Expr {
  const UnaryExpr(
    this.op,
    this.operand, {
    required super.offset,
    required super.length,
  });

  final UnaryOp op;
  final Expr operand;

  @override
  ExprPrecedence get precedence => op.precedence;

  @override
  String toSource() {
    final inner = Expr.wrap(operand, op.precedence);
    return op == UnaryOp.not ? 'not $inner' : '-$inner';
  }
}

enum BinaryOp {
  or('or', ExprPrecedence.or),
  and('and', ExprPrecedence.and),
  equal('=', ExprPrecedence.comparison),
  notEqual('<>', ExprPrecedence.comparison),
  less('<', ExprPrecedence.comparison),
  lessOrEqual('<=', ExprPrecedence.comparison),
  greater('>', ExprPrecedence.comparison),
  greaterOrEqual('>=', ExprPrecedence.comparison),
  add('+', ExprPrecedence.additive),
  subtract('-', ExprPrecedence.additive),
  multiply('*', ExprPrecedence.multiplicative),
  divide('/', ExprPrecedence.multiplicative),
  modulo('%', ExprPrecedence.multiplicative);

  const BinaryOp(this.symbol, this.precedence);
  final String symbol;
  final ExprPrecedence precedence;

  bool get isComparison => precedence == ExprPrecedence.comparison;
  bool get isLogical => this == and || this == or;
  bool get isArithmetic =>
      precedence == ExprPrecedence.additive ||
      precedence == ExprPrecedence.multiplicative;
}

final class BinaryExpr extends Expr {
  const BinaryExpr(
    this.op,
    this.left,
    this.right, {
    required super.offset,
    required super.length,
  });

  final BinaryOp op;
  final Expr left;
  final Expr right;

  @override
  ExprPrecedence get precedence => op.precedence;

  @override
  String toSource() {
    // Left-associative: the right operand needs parentheses at equal
    // precedence (a - (b - c)); comparisons are not associative at all.
    final l = Expr.wrap(left, op.precedence, strict: op.isComparison);
    final r = Expr.wrap(right, op.precedence, strict: true);
    return '$l ${op.symbol} $r';
  }
}

/// `subject [not] in (a, b, …)`.
final class InExpr extends Expr {
  const InExpr(
    this.subject,
    this.values, {
    this.negated = false,
    required super.offset,
    required super.length,
  });

  final Expr subject;
  final List<Expr> values;
  final bool negated;

  @override
  ExprPrecedence get precedence => ExprPrecedence.comparison;

  @override
  String toSource() {
    final s = Expr.wrap(subject, ExprPrecedence.comparison, strict: true);
    final list = values.map((v) => v.toSource()).join(', ');
    return '$s ${negated ? 'not in' : 'in'} ($list)';
  }
}

/// `subject [not] between low and high` (inclusive).
final class BetweenExpr extends Expr {
  const BetweenExpr(
    this.subject,
    this.low,
    this.high, {
    this.negated = false,
    required super.offset,
    required super.length,
  });

  final Expr subject;
  final Expr low;
  final Expr high;
  final bool negated;

  @override
  ExprPrecedence get precedence => ExprPrecedence.comparison;

  @override
  String toSource() {
    final s = Expr.wrap(subject, ExprPrecedence.comparison, strict: true);
    final lo = Expr.wrap(low, ExprPrecedence.comparison, strict: true);
    final hi = Expr.wrap(high, ExprPrecedence.comparison, strict: true);
    return '$s ${negated ? 'not between' : 'between'} $lo and $hi';
  }
}

/// `subject is [not] empty` (`null` accepted for `empty`).
final class IsEmptyExpr extends Expr {
  const IsEmptyExpr(
    this.subject, {
    this.negated = false,
    required super.offset,
    required super.length,
  });

  final Expr subject;
  final bool negated;

  @override
  ExprPrecedence get precedence => ExprPrecedence.comparison;

  @override
  String toSource() {
    final s = Expr.wrap(subject, ExprPrecedence.comparison, strict: true);
    return '$s ${negated ? 'is not empty' : 'is empty'}';
  }
}

/// `name(arguments)`: a built-in or registered function, `if`, `coalesce`,
/// or an aggregate (`sum(total)`) in a cell formula.
final class CallExpr extends Expr {
  const CallExpr(
    this.name,
    this.arguments, {
    required this.nameLength,
    required super.offset,
    required super.length,
  });

  /// The name as written; matched case-insensitively.
  final String name;

  /// Length of the name token, for error ranges.
  final int nameLength;
  final List<Expr> arguments;

  @override
  String toSource() =>
      '${name.toLowerCase()}(${arguments.map((a) => a.toSource()).join(', ')})';
}
