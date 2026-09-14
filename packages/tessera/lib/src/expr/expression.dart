import '../facts/fact_table.dart';
import '../facts/fact_table_impl.dart';
import 'ast.dart';
import 'checker.dart';
import 'compiler.dart';
import 'expr_type.dart';
import 'expression_error.dart';
import 'parser.dart';

/// A parsed expression of Tessera's expression language.
///
/// The language is a small, side-effect free formula language for filters
/// (`total > 100 and region = "Europe"`), calculated measures
/// (`quantity * unit_price * (1 - discount)`), expression dimensions
/// (`if(total > 100, "big", "small")`) and cell formulas
/// (`sum(total) / count`). See the package documentation for the grammar.
///
/// Parsing checks the syntax only; [check] resolves names against a scope
/// and infers types; the engine compiles the result to closures over the
/// fact table's columns. Every error is an [ExpressionError] with a source
/// range.
final class Expression {
  const Expression._(this.source, this.root);

  /// Parses [source]; throws [ExpressionError].
  factory Expression.parse(String source) =>
      Expression._(source, parseExpression(source));

  /// Parses [source], or returns `null` when it does not parse.
  static Expression? tryParse(String source) {
    try {
      return Expression.parse(source);
    } on ExpressionError {
      return null;
    }
  }

  /// The first problem with [source] in [scope] (and, with [expected], as
  /// an expression of that type), or `null` when it is valid. What an
  /// editor calls on every keystroke.
  static ExpressionError? validate(
    String source, {
    required ExpressionScope scope,
    ExprType? expected,
  }) {
    try {
      Expression.parse(source).check(scope, expected: expected);
      return null;
    } on ExpressionError catch (e) {
      return e;
    }
  }

  final String source;
  final Expr root;

  /// The names the expression refers to (columns; in a cell formula the
  /// columns inside aggregates and `count`).
  Set<String> get names {
    final out = <String>{};
    void visit(Expr e) {
      switch (e) {
        case NameRef(:final name):
          out.add(name);
        case UnaryExpr(:final operand):
          visit(operand);
        case BinaryExpr(:final left, :final right):
          visit(left);
          visit(right);
        case InExpr(:final subject, :final values):
          visit(subject);
          values.forEach(visit);
        case BetweenExpr(:final subject, :final low, :final high):
          visit(subject);
          visit(low);
          visit(high);
        case IsEmptyExpr(:final subject):
          visit(subject);
        case CallExpr(:final arguments):
          arguments.forEach(visit);
        case NumberLiteral() ||
            TextLiteral() ||
            BooleanLiteral() ||
            DateLiteral() ||
            NullLiteral():
          break;
      }
    }

    visit(root);
    return out;
  }

  /// Resolves names and types in [scope]; throws [ExpressionError].
  CheckedExpression check(ExpressionScope scope, {ExprType? expected}) =>
      checkExpression(source, root, scope, expected: expected);

  /// Checks the expression against [facts] and compiles it to closures over
  /// its columns (row scope). Throws [ExpressionError].
  CompiledExpression compile(
    FactTable facts, {
    ExpressionScope? scope,
    ExprType? expected,
  }) {
    final s = scope ?? ExpressionScope.ofFacts(facts);
    final checked = check(s, expected: expected);
    return compileExpression(checked, RowBindings(facts as FactTableImpl));
  }

  /// The canonical source text (see [Expr.toSource]).
  String get canonicalSource => root.toSource();

  @override
  bool operator ==(Object other) =>
      other is Expression && other.source == source;

  @override
  int get hashCode => source.hashCode;

  @override
  String toString() => source;
}
