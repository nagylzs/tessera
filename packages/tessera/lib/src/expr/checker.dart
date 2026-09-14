import '../cube/aggregate.dart';
import '../facts/dimension.dart';
import '../facts/fact_table.dart';
import '../facts/measure.dart';
import '../schema/schema.dart';
import 'ast.dart';
import 'expr_type.dart';
import 'expression_error.dart';
import 'functions.dart';

/// What names an expression may refer to and which functions it may call.
///
/// A *row* scope (`ExpressionScope.rows`) is the context of a filter, a
/// calculated measure or an expression dimension: names are columns and
/// the expression is evaluated once per fact. A *cell* scope
/// (`ExpressionScope.cells`) is the context of a cell formula: names are
/// aggregates — `sum(total)`, `avg(price)`, `min(x)`, `max(x)`,
/// `count` / `count()` (facts), `count(x)` (non-empty values),
/// `distinct(x)` — over the same columns, and the expression is evaluated
/// once per cell from the accumulated results.
final class ExpressionScope {
  const ExpressionScope._(this.columns, this._functions, this.isCellScope);

  /// Column name → type, for a row expression.
  const ExpressionScope.rows(
    Map<String, ExprType> columns, {
    FunctionRegistry? functions,
  }) : this._(columns, functions, false);

  /// Column name → type, for a cell formula over aggregates of the columns.
  const ExpressionScope.cells(
    Map<String, ExprType> columns, {
    FunctionRegistry? functions,
  }) : this._(columns, functions, true);

  /// Row scope over the columns of [facts].
  ExpressionScope.ofFacts(FactTable facts, {FunctionRegistry? functions})
    : this._(columnTypesOf(facts), functions, false);

  /// Row scope over the included columns of [schema].
  ExpressionScope.ofSchema(Schema schema, {FunctionRegistry? functions})
    : this._(
        {for (final c in schema.included) c.name: ExprType.of(c.type)},
        functions,
        false,
      );

  /// Cell scope over the columns of [facts].
  ExpressionScope.cellsOf(FactTable facts, {FunctionRegistry? functions})
    : this._(columnTypesOf(facts), functions, true);

  final Map<String, ExprType> columns;
  final FunctionRegistry? _functions;
  final bool isCellScope;

  FunctionRegistry get functions => _functions ?? FunctionRegistry.standard();

  static Map<String, ExprType> columnTypesOf(FactTable facts) => {
    for (final c in facts.columns) c.name: ExprType.of(c.type),
  };

  ExpressionScope copyWith({
    Map<String, ExprType>? columns,
    FunctionRegistry? functions,
    bool? isCellScope,
  }) => ExpressionScope._(
    columns ?? this.columns,
    functions ?? _functions,
    isCellScope ?? this.isCellScope,
  );
}

/// A parsed expression whose names are resolved and whose types are known:
/// the input of the compiler.
final class CheckedExpression {
  CheckedExpression._({
    required this.source,
    required this.root,
    required this.type,
    required this.scope,
    required Map<Expr, ExprType?> types,
    required Map<CallExpr, ExpressionFunction> functions,
    required Map<Expr, Aggregate> aggregates,
    required Set<String> columns,
  }) : _types = Map<Expr, ExprType?>.unmodifiable(types),
       _functions = Map<CallExpr, ExpressionFunction>.unmodifiable(functions),
       _aggregates = Map<Expr, Aggregate>.unmodifiable(aggregates),
       columns = Set.unmodifiable(columns),
       dependencies = List.unmodifiable(
         aggregates.values.toSet().toList(growable: false),
       );

  final String source;
  final Expr root;

  /// The type of the whole expression.
  final ExprType type;
  final ExpressionScope scope;
  final Map<Expr, ExprType?> _types;
  final Map<CallExpr, ExpressionFunction> _functions;
  final Map<Expr, Aggregate> _aggregates;

  /// Columns the expression reads (through aggregates in a cell formula).
  final Set<String> columns;

  /// Cell formulas: the aggregates whose results the formula needs, in
  /// first-use order. Empty for row expressions.
  final List<Aggregate> dependencies;

  /// The type of a node; `null` for a `null` literal (or an `if` /
  /// `coalesce` of nulls that another branch types).
  ExprType? typeOf(Expr node) => _types[node];

  /// The function a call resolved to; `null` for `if`, `coalesce`,
  /// `isempty` and aggregate references.
  ExpressionFunction? functionOf(CallExpr call) => _functions[call];

  /// The aggregate a name or call denotes in a cell formula.
  Aggregate? aggregateOf(Expr node) => _aggregates[node];
}

/// Resolves names and infers types; throws [ExpressionError] on the first
/// problem. With [expected], the whole expression must have that type.
CheckedExpression checkExpression(
  String source,
  Expr root,
  ExpressionScope scope, {
  ExprType? expected,
}) {
  final c = _Checker(scope);
  final type = c.visit(root);
  if (type == null) {
    throw ExpressionError(
      ExpressionErrorKind.unknownType,
      offset: root.offset,
      length: root.length,
    );
  }
  if (expected != null && type != expected) {
    throw ExpressionError(
      ExpressionErrorKind.resultType,
      offset: root.offset,
      length: root.length,
      arguments: [expected.name, type.name],
    );
  }
  return CheckedExpression._(
    source: source,
    root: root,
    type: type,
    scope: scope,
    types: c.types,
    functions: c.functions,
    aggregates: c.aggregates,
    columns: c.columns,
  );
}

final class _Checker {
  _Checker(this.scope);

  final ExpressionScope scope;
  final types = <Expr, ExprType?>{};
  final functions = <CallExpr, ExpressionFunction>{};
  final aggregates = <Expr, Aggregate>{};
  final columns = <String>{};

  Never fail(
    Expr at,
    ExpressionErrorKind kind, [
    List<String> args = const [],
  ]) {
    throw ExpressionError(
      kind,
      offset: at.offset,
      length: at.length,
      arguments: args,
    );
  }

  static String _name(ExprType? t) => t?.name ?? 'null';

  ExprType? visit(Expr e) => types[e] = _type(e);

  ExprType? _type(Expr e) => switch (e) {
    NumberLiteral() => ExprType.number,
    TextLiteral() => ExprType.text,
    BooleanLiteral() => ExprType.boolean,
    DateLiteral() => ExprType.date,
    NullLiteral() => null,
    NameRef() => _nameRef(e),
    UnaryExpr() => _unary(e),
    BinaryExpr() => _binary(e),
    InExpr() => _in(e),
    BetweenExpr() => _between(e),
    IsEmptyExpr() => _isEmpty(e),
    CallExpr() => _call(e),
  };

  ExprType _column(Expr at, String name) {
    final t = scope.columns[name];
    if (t == null) fail(at, ExpressionErrorKind.unknownColumn, [name]);
    columns.add(name);
    return t;
  }

  ExprType _nameRef(NameRef e) {
    if (scope.isCellScope) {
      if (e.name.toLowerCase() == 'count') {
        aggregates[e] = Aggregate.count;
        return ExprType.number;
      }
      if (scope.columns.containsKey(e.name)) {
        fail(e, ExpressionErrorKind.notAllowedHere, [e.name]);
      }
      fail(e, ExpressionErrorKind.unknownColumn, [e.name]);
    }
    return _column(e, e.name);
  }

  /// Checks that [actual] is [expected] or null; returns [expected].
  ExprType _require(
    Expr at,
    ExprType? actual,
    ExprType expected,
    String operator,
  ) {
    if (actual != null && actual != expected) {
      fail(at, ExpressionErrorKind.operandType, [
        operator,
        expected.name,
        actual.name,
      ]);
    }
    return expected;
  }

  ExprType _unary(UnaryExpr e) {
    final t = visit(e.operand);
    return switch (e.op) {
      UnaryOp.negate => _require(e.operand, t, ExprType.number, '-'),
      UnaryOp.not => _require(e.operand, t, ExprType.boolean, 'not'),
    };
  }

  ExprType? _binary(BinaryExpr e) {
    final l = visit(e.left), r = visit(e.right);
    final op = e.op;
    if (op.isLogical) {
      _require(e.left, l, ExprType.boolean, op.symbol);
      _require(e.right, r, ExprType.boolean, op.symbol);
      return ExprType.boolean;
    }
    if (op.isComparison) {
      final t = _unify(e, l, r, op.symbol);
      if (t == null) return ExprType.boolean;
      if (op != BinaryOp.equal && op != BinaryOp.notEqual && !t.isOrdered) {
        fail(e, ExpressionErrorKind.incompatibleTypes, [
          op.symbol,
          _name(l),
          _name(r),
        ]);
      }
      return ExprType.boolean;
    }
    // Arithmetic.
    if (l == null && r == null) return null;
    final isAdd = op == BinaryOp.add, isSub = op == BinaryOp.subtract;
    if (l == ExprType.date || r == ExprType.date) {
      // date ± number → date, number + date → date, date - date → number.
      if (isAdd && (l == null || l == ExprType.number) && r == ExprType.date) {
        return ExprType.date;
      }
      if ((isAdd || isSub) &&
          l == ExprType.date &&
          (r == null || r == ExprType.number)) {
        return ExprType.date;
      }
      if (isSub && l == ExprType.date && r == ExprType.date) {
        return ExprType.number;
      }
      // A null operand next to a date: the other side decides.
      if (l == null && r == ExprType.date && isSub) return ExprType.date;
      fail(e, ExpressionErrorKind.incompatibleTypes, [
        op.symbol,
        _name(l),
        _name(r),
      ]);
    }
    _require(e.left, l, ExprType.number, op.symbol);
    _require(e.right, r, ExprType.number, op.symbol);
    return ExprType.number;
  }

  /// The common type of two operands, `null` if both are null.
  ExprType? _unify(Expr at, ExprType? l, ExprType? r, String operator) {
    if (l == null) return r;
    if (r == null) return l;
    if (l != r) {
      fail(at, ExpressionErrorKind.incompatibleTypes, [
        operator,
        l.name,
        r.name,
      ]);
    }
    return l;
  }

  ExprType _in(InExpr e) {
    var t = visit(e.subject);
    for (final v in e.values) {
      t = _unify(v, t, visit(v), 'in');
    }
    return ExprType.boolean;
  }

  ExprType _between(BetweenExpr e) {
    var t = visit(e.subject);
    t = _unify(e.low, t, visit(e.low), 'between');
    t = _unify(e.high, t, visit(e.high), 'between');
    if (t != null && !t.isOrdered) {
      fail(e, ExpressionErrorKind.operandType, [
        'between',
        'number, text or date',
        t.name,
      ]);
    }
    return ExprType.boolean;
  }

  ExprType _isEmpty(IsEmptyExpr e) {
    visit(e.subject);
    return ExprType.boolean;
  }

  static const _aggregateNames = {
    'sum',
    'avg',
    'average',
    'min',
    'max',
    'count',
    'distinct',
    'stdev',
    'stdevp',
    'var',
    'varp',
  };

  ExprType? _call(CallExpr e) {
    final name = e.name.toLowerCase();
    final args = e.arguments;
    switch (name) {
      case 'if':
        _arity(e, name, '3', 3);
        _require(args[0], visit(args[0]), ExprType.boolean, 'if');
        final a = visit(args[1]), b = visit(args[2]);
        return _unify(e, a, b, 'if');
      case 'coalesce':
        if (args.isEmpty) _arity(e, name, 'at least 1', 0);
        ExprType? t;
        for (final a in args) {
          t = _unify(a, t, visit(a), 'coalesce');
        }
        return t;
      case 'isempty':
        _arity(e, name, '1', 1);
        visit(args[0]);
        return ExprType.boolean;
    }
    if (scope.isCellScope && _aggregateNames.contains(name)) {
      final agg = _aggregate(e, name);
      if (agg != null) {
        aggregates[e] = agg;
        return ExprType.number;
      }
    }
    final overloads = scope.functions.lookup(name);
    if (overloads.isEmpty) {
      throw ExpressionError(
        ExpressionErrorKind.unknownFunction,
        offset: e.offset,
        length: e.nameLength,
        arguments: [e.name],
      );
    }
    final argTypes = [for (final a in args) visit(a)];
    final byCount = overloads.where((f) => f.acceptsCount(args.length));
    if (byCount.isEmpty) {
      final arities = overloads
          .map((f) => f.arityDescription)
          .toSet()
          .join(' or ');
      _arity(e, name, arities, -1);
    }
    for (final f in byCount) {
      if (_matches(f, argTypes)) {
        functions[e] = f;
        return f.returns;
      }
    }
    // Report against the first overload of this arity.
    final f = byCount.first;
    for (var i = 0; i < args.length; i++) {
      final p = f.parameterAt(i)!;
      final t = argTypes[i];
      if (t != null && t != p) {
        fail(args[i], ExpressionErrorKind.argumentType, [
          name,
          '${i + 1}',
          p.name,
          t.name,
        ]);
      }
    }
    throw StateError('unreachable');
  }

  static bool _matches(ExpressionFunction f, List<ExprType?> argTypes) {
    for (var i = 0; i < argTypes.length; i++) {
      final t = argTypes[i];
      if (t != null && t != f.parameterAt(i)) return false;
    }
    return true;
  }

  void _arity(CallExpr e, String name, String expected, int required) {
    if (required >= 0 && e.arguments.length == required) return;
    fail(e, ExpressionErrorKind.argumentCount, [
      name,
      expected,
      '${e.arguments.length}',
    ]);
  }

  /// `sum(col)` etc. in a cell formula, or `null` when the call does not
  /// have the shape of an aggregate (then it is looked up as a function).
  Aggregate? _aggregate(CallExpr e, String name) {
    final args = e.arguments;
    // min/max with other shapes are the plain functions.
    final aggregateOnly = name != 'min' && name != 'max';
    if (args.length != 1) {
      if (name == 'count' && args.isEmpty) return Aggregate.count;
      if (!aggregateOnly) return null;
      _arity(e, name, name == 'count' ? '0-1' : '1', -1);
    }
    if (args.single is! NameRef) {
      if (!aggregateOnly) return null;
      fail(args.single, ExpressionErrorKind.argumentType, [
        name,
        '1',
        'a column name',
        'an expression',
      ]);
    }
    final ref = args.single as NameRef;
    final t = scope.columns[ref.name];
    if (t == null) fail(ref, ExpressionErrorKind.unknownColumn, [ref.name]);
    columns.add(ref.name);
    types[ref] = t;
    if (name != 'distinct' && t != ExprType.number) {
      fail(ref, ExpressionErrorKind.argumentType, [
        name,
        '1',
        'number',
        t.name,
      ]);
    }
    return aggregateOfShape(name, ref.name)!;
  }
}

/// The aggregate a cell-formula call denotes by its shape alone (no type
/// check): `count` / `count()` → facts, `sum|avg|average|min|max|count(col)`,
/// `distinct(col)`; `null` otherwise.
Aggregate? aggregateOfShape(String name, String? column) {
  if (column == null) return name == 'count' ? Aggregate.count : null;
  final m = Measure(column);
  return switch (name.toLowerCase()) {
    'sum' => Aggregate.sum(m),
    'avg' || 'average' => Aggregate.average(m),
    'min' => Aggregate.min(m),
    'max' => Aggregate.max(m),
    'count' => Aggregate.countNonNull(m),
    'stdev' => Aggregate.stdDev(m),
    'stdevp' => Aggregate.stdDevPopulation(m),
    'var' => Aggregate.variance(m),
    'varp' => Aggregate.variancePopulation(m),
    'distinct' => Aggregate.distinctCount(ColumnDimension(column)),
    _ => null,
  };
}

/// The aggregates a cell formula refers to, by shape, in first-use order.
/// What [ExpressionAggregate.dependencies] is before any fact table is
/// known; the checker verifies the column types later.
List<Aggregate> aggregateReferences(Expr root) {
  final out = <Aggregate>[];
  void add(Aggregate? a) {
    if (a != null && !out.contains(a)) out.add(a);
  }

  void visit(Expr e) {
    switch (e) {
      case NameRef(:final name):
        if (name.toLowerCase() == 'count') add(Aggregate.count);
      case CallExpr(:final name, :final arguments):
        final lower = name.toLowerCase();
        if (arguments.isEmpty) {
          add(aggregateOfShape(lower, null));
        } else if (arguments.length == 1 && arguments.single is NameRef) {
          add(aggregateOfShape(lower, (arguments.single as NameRef).name));
        }
        arguments.forEach(visit);
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
