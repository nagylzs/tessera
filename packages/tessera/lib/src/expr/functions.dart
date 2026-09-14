import 'expr_type.dart';

/// A function callable from expressions: its signature for the checker and,
/// for functions supplied by an application, the Dart implementation.
///
/// Built-in functions have no [implementation]; the compiler knows them by
/// name and emits typed code. An application function receives its
/// arguments boxed — `double?` for numbers, `String?` for text, `bool?` for
/// booleans, UTC `DateTime?` for dates — and returns a value of the same
/// kinds (or `null`). It must be pure: it may be called any number of times,
/// in any order, once per fact.
final class ExpressionFunction {
  const ExpressionFunction(
    this.name, {
    required this.parameters,
    required this.returns,
    this.optional = 0,
    this.variadic = false,
    this.implementation,
  });

  /// The name as written in expressions, matched case-insensitively.
  final String name;

  /// Parameter types in order. With [variadic], the last one may repeat.
  final List<ExprType> parameters;

  /// How many trailing parameters may be omitted.
  final int optional;

  /// Whether the last parameter accepts any number of further arguments.
  final bool variadic;

  final ExprType returns;

  final Object? Function(List<Object?> arguments)? implementation;

  int get minArguments => parameters.length - optional;

  /// `null` when [variadic].
  int? get maxArguments => variadic ? null : parameters.length;

  bool acceptsCount(int n) =>
      n >= minArguments && (variadic || n <= parameters.length);

  /// The parameter type of argument [i] (0-based), or `null` beyond the
  /// signature.
  ExprType? parameterAt(int i) {
    if (i < parameters.length) return parameters[i];
    return variadic ? parameters.last : null;
  }

  /// `"2"`, `"1-2"` or `"at least 1"`: the argument count for messages.
  String get arityDescription {
    if (variadic) return 'at least $minArguments';
    if (optional == 0) return '$minArguments';
    return '$minArguments-${parameters.length}';
  }

  @override
  String toString() =>
      '$name(${parameters.map((p) => p.name).join(', ')}${variadic ? '…' : ''}) → ${returns.name}';
}

/// The functions an expression may call: the built-in set plus whatever an
/// application adds. Immutable; [withFunctions] returns an extended copy.
///
/// Several functions may share a name with different parameter types
/// (`date(text)` and `date(number, number, number)`); the checker picks the
/// one whose signature fits.
final class FunctionRegistry {
  FunctionRegistry._(Map<String, List<ExpressionFunction>> byName)
    : _byName = Map<String, List<ExpressionFunction>>.unmodifiable({
        for (final e in byName.entries)
          e.key: List<ExpressionFunction>.unmodifiable(e.value),
      });

  /// The built-in functions only.
  factory FunctionRegistry.standard() => _standard;

  /// A registry with no functions at all.
  factory FunctionRegistry.empty() => FunctionRegistry._(const {});

  static final _standard = FunctionRegistry.empty().withFunctions(
    builtInFunctions,
  );

  final Map<String, List<ExpressionFunction>> _byName;

  /// Every registered function.
  Iterable<ExpressionFunction> get functions => _byName.values.expand((l) => l);

  /// The overloads of [name] (any case), empty when unknown.
  List<ExpressionFunction> lookup(String name) =>
      _byName[name.toLowerCase()] ?? const [];

  bool contains(String name) => _byName.containsKey(name.toLowerCase());

  /// This registry plus [added]; a function with the same name and
  /// parameter types as an existing one replaces it.
  FunctionRegistry withFunctions(Iterable<ExpressionFunction> added) {
    final next = {
      for (final e in _byName.entries) e.key: [...e.value],
    };
    for (final f in added) {
      final list = next.putIfAbsent(f.name.toLowerCase(), () => []);
      list.removeWhere(
        (g) =>
            g.variadic == f.variadic &&
            g.parameters.length == f.parameters.length &&
            _sameTypes(g.parameters, f.parameters),
      );
      list.add(f);
    }
    return FunctionRegistry._(next);
  }

  FunctionRegistry withFunction(ExpressionFunction added) =>
      withFunctions([added]);

  static bool _sameTypes(List<ExprType> a, List<ExprType> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

const _n = ExprType.number;
const _t = ExprType.text;
const _b = ExprType.boolean;
const _d = ExprType.date;

/// The built-in functions, by signature. `if`, `coalesce` and `isempty`
/// take arguments of any (matching) type and are handled by the checker
/// itself, so they are not listed here.
///
/// Numbers: `abs(n)`, `round(n[, digits])`, `floor(n)`, `ceil(n)`,
/// `sqrt(n)`, `min(n, …)`, `max(n, …)`, `number(text)`.
/// Text: `len(t)`, `lower(t)`, `upper(t)`, `trim(t)`, `left(t, n)`,
/// `right(t, n)`, `substring(t, start[, length])` (1-based),
/// `contains(t, part)`, `startswith(t, part)`, `endswith(t, part)`,
/// `replace(t, from, to)`, `concat(t, …)`, `text(number | date | boolean)`.
/// Dates: `year(d)`, `quarter(d)`, `month(d)`, `week(d)` (ISO),
/// `day(d)`, `weekday(d)` (1 = Monday), `hour(d)`, `date(text)`,
/// `date(year, month, day)`, `today()`.
const builtInFunctions = <ExpressionFunction>[
  ExpressionFunction('abs', parameters: [_n], returns: _n),
  ExpressionFunction('round', parameters: [_n, _n], optional: 1, returns: _n),
  ExpressionFunction('floor', parameters: [_n], returns: _n),
  ExpressionFunction('ceil', parameters: [_n], returns: _n),
  ExpressionFunction('sqrt', parameters: [_n], returns: _n),
  ExpressionFunction('min', parameters: [_n], variadic: true, returns: _n),
  ExpressionFunction('max', parameters: [_n], variadic: true, returns: _n),
  ExpressionFunction('number', parameters: [_t], returns: _n),
  ExpressionFunction('len', parameters: [_t], returns: _n),
  ExpressionFunction('lower', parameters: [_t], returns: _t),
  ExpressionFunction('upper', parameters: [_t], returns: _t),
  ExpressionFunction('trim', parameters: [_t], returns: _t),
  ExpressionFunction('left', parameters: [_t, _n], returns: _t),
  ExpressionFunction('right', parameters: [_t, _n], returns: _t),
  ExpressionFunction(
    'substring',
    parameters: [_t, _n, _n],
    optional: 1,
    returns: _t,
  ),
  ExpressionFunction('contains', parameters: [_t, _t], returns: _b),
  ExpressionFunction('startswith', parameters: [_t, _t], returns: _b),
  ExpressionFunction('endswith', parameters: [_t, _t], returns: _b),
  ExpressionFunction('replace', parameters: [_t, _t, _t], returns: _t),
  ExpressionFunction('concat', parameters: [_t], variadic: true, returns: _t),
  ExpressionFunction('text', parameters: [_n], returns: _t),
  ExpressionFunction('text', parameters: [_d], returns: _t),
  ExpressionFunction('text', parameters: [_b], returns: _t),
  ExpressionFunction('year', parameters: [_d], returns: _n),
  ExpressionFunction('quarter', parameters: [_d], returns: _n),
  ExpressionFunction('month', parameters: [_d], returns: _n),
  ExpressionFunction('week', parameters: [_d], returns: _n),
  ExpressionFunction('day', parameters: [_d], returns: _n),
  ExpressionFunction('weekday', parameters: [_d], returns: _n),
  ExpressionFunction('hour', parameters: [_d], returns: _n),
  ExpressionFunction('date', parameters: [_t], returns: _d),
  ExpressionFunction('date', parameters: [_n, _n, _n], returns: _d),
  ExpressionFunction('today', parameters: [], returns: _d),
];
