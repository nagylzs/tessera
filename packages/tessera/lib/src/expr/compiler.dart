import 'dart:math' as math;
import 'dart:typed_data';

import '../cube/aggregate.dart';
import '../facts/dimension.dart';
import '../facts/fact_table_impl.dart';
import 'ast.dart';
import 'checker.dart';
import 'expr_type.dart';
import 'parser.dart';

// Compiles a CheckedExpression into closures over an int index. Numbers and
// dates are `double Function(int)` with NaN for null (dates are UTC
// milliseconds, as in the fact table); text is `String? Function(int)`;
// booleans are `bool? Function(int)` with SQL three-valued logic. Column
// reads go straight to the typed arrays of FactTableImpl, so evaluating a
// row allocates nothing.

typedef NumberFn = double Function(int index);
typedef TextFn = String? Function(int index);
typedef BoolFn = bool? Function(int index);
typedef BoxedFn = Object? Function(int index);

const double _nan = double.nan;
const double _msPerDay = 86400000;

/// Where compiled closures read their inputs: the columns of a fact table
/// (row scope) or the results of a cell's aggregates (cell scope).
abstract interface class ExpressionBindings {
  /// The [TextColumn] behind [name] when there is one (for code-level
  /// comparisons), otherwise `null`.
  TextColumn? textColumn(String name);

  NumberFn number(String name);
  TextFn text(String name);
  BoolFn boolean(String name);
  NumberFn date(String name);

  /// Cell formulas: the numeric result of [aggregate] for the cell at the
  /// index passed to the closure.
  NumberFn aggregate(Aggregate aggregate);
}

/// Bindings over the columns of a fact table.
final class RowBindings implements ExpressionBindings {
  const RowBindings(this.facts);

  final FactTableImpl facts;

  @override
  TextColumn? textColumn(String name) {
    final c = facts.column(name);
    return c is TextColumn ? c : null;
  }

  @override
  NumberFn number(String name) {
    final c = facts.column(name) as NumberColumn;
    final data = c.data;
    return (i) => data[i];
  }

  @override
  NumberFn date(String name) {
    final c = facts.column(name) as DateColumn;
    final data = c.data;
    return (i) => data[i];
  }

  @override
  TextFn text(String name) {
    final c = facts.column(name) as TextColumn;
    final codes = c.codes, dict = c.dictionary;
    return (i) {
      final code = codes[i];
      return code < 0 ? null : dict[code];
    };
  }

  @override
  BoolFn boolean(String name) {
    final c = facts.column(name) as BoolColumn;
    final data = c.data;
    return (i) => switch (data[i]) {
      0 => false,
      1 => true,
      _ => null,
    };
  }

  @override
  NumberFn aggregate(Aggregate aggregate) =>
      throw StateError('aggregates are not available in a row expression');
}

/// Bindings for a cell formula: the closures read [slot], a table the
/// caller fills with one entry per aggregate of [aggregates] (`NaN` = null)
/// before evaluating a cell; the index passed to the closure is ignored.
final class CellBindings implements ExpressionBindings {
  CellBindings(this.aggregates, this.slot);

  final List<Aggregate> aggregates;

  /// `slot[k]` = the result of `aggregates[k]` for the current cell.
  final Float64List slot;

  @override
  TextColumn? textColumn(String name) => null;

  Never _noColumns() =>
      throw StateError('columns are not available in a cell formula');

  @override
  NumberFn number(String name) => _noColumns();
  @override
  TextFn text(String name) => _noColumns();
  @override
  BoolFn boolean(String name) => _noColumns();
  @override
  NumberFn date(String name) => _noColumns();

  @override
  NumberFn aggregate(Aggregate aggregate) {
    final k = aggregates.indexOf(aggregate);
    if (k < 0) throw ArgumentError.value(aggregate.id, 'aggregate', 'unknown');
    final s = slot;
    return (_) => s[k];
  }
}

/// A compiled expression: one typed closure, plus a boxed view.
final class CompiledExpression {
  CompiledExpression._(this.type, this._number, this._text, this._boolean);

  final ExprType type;
  final NumberFn? _number;
  final TextFn? _text;
  final BoolFn? _boolean;

  /// Numbers, or dates as UTC milliseconds; NaN for null. Only for
  /// [ExprType.number] and [ExprType.date].
  NumberFn get asNumber => _number!;

  /// Only for [ExprType.text].
  TextFn get asText => _text!;

  /// Only for [ExprType.boolean].
  BoolFn get asBoolean => _boolean!;

  /// The value at [index] boxed: `double?`, `String?`, `bool?` or a UTC
  /// `DateTime?`.
  Object? evaluate(int index) => switch (type) {
    ExprType.number => _unbox(_number!(index)),
    ExprType.date => _dateOf(_number!(index)),
    ExprType.text => _text!(index),
    ExprType.boolean => _boolean!(index),
  };

  static double? _unbox(double v) => v.isNaN ? null : v;
  static DateTime? _dateOf(double v) => v.isNaN
      ? null
      : DateTime.fromMillisecondsSinceEpoch(v.toInt(), isUtc: true);
}

CompiledExpression compileExpression(
  CheckedExpression checked,
  ExpressionBindings bindings,
) {
  final c = _Compiler(checked, bindings);
  final root = checked.root;
  return switch (checked.type) {
    ExprType.number || ExprType.date => CompiledExpression._(
      checked.type,
      c.number(root),
      null,
      null,
    ),
    ExprType.text => CompiledExpression._(
      checked.type,
      null,
      c.text(root),
      null,
    ),
    ExprType.boolean => CompiledExpression._(
      checked.type,
      null,
      null,
      c.boolean(root),
    ),
  };
}

final class _Compiler {
  _Compiler(this.checked, this.bindings);

  final CheckedExpression checked;
  final ExpressionBindings bindings;

  ExprType? typeOf(Expr e) => checked.typeOf(e);

  // ------------------------------------------------------------- number

  /// A closure for a number- or date-typed node (or a null literal).
  NumberFn number(Expr e) {
    switch (e) {
      case NumberLiteral(:final value):
        return (_) => value;
      case DateLiteral(:final value):
        final ms = value.millisecondsSinceEpoch.toDouble();
        return (_) => ms;
      case NullLiteral():
        return (_) => _nan;
      case NameRef(:final name):
        final agg = checked.aggregateOf(e);
        if (agg != null) return bindings.aggregate(agg);
        return typeOf(e) == ExprType.date
            ? bindings.date(name)
            : bindings.number(name);
      case UnaryExpr(:final operand):
        final f = number(operand);
        return (i) => -f(i);
      case BinaryExpr(:final op, :final left, :final right):
        return _arithmetic(e, op, left, right);
      case CallExpr():
        return _numberCall(e);
      case InExpr() ||
          BetweenExpr() ||
          IsEmptyExpr() ||
          TextLiteral() ||
          BooleanLiteral():
        throw StateError('not a number: $e');
    }
  }

  NumberFn _arithmetic(BinaryExpr e, BinaryOp op, Expr left, Expr right) {
    final lt = typeOf(left), rt = typeOf(right), t = typeOf(e);
    final a = number(left), b = number(right);
    if (t == ExprType.date || (lt == ExprType.date && rt == ExprType.date)) {
      if (lt == ExprType.date && rt == ExprType.date) {
        // date - date → days
        return (i) => (a(i) - b(i)) / _msPerDay;
      }
      if (lt == ExprType.date) {
        return op == BinaryOp.add
            ? (i) => a(i) + b(i) * _msPerDay
            : (i) => a(i) - b(i) * _msPerDay;
      }
      // number + date
      return (i) => a(i) * _msPerDay + b(i);
    }
    // NaN propagates through + - * on its own.
    return switch (op) {
      BinaryOp.add => (i) => a(i) + b(i),
      BinaryOp.subtract => (i) => a(i) - b(i),
      BinaryOp.multiply => (i) => a(i) * b(i),
      BinaryOp.divide => (i) {
        final d = b(i);
        return d == 0 ? _nan : a(i) / d;
      },
      BinaryOp.modulo => (i) {
        final d = b(i);
        return d == 0 ? _nan : a(i) % d;
      },
      _ => throw StateError('not arithmetic: $op'),
    };
  }

  NumberFn _numberCall(CallExpr e) {
    final agg = checked.aggregateOf(e);
    if (agg != null) return bindings.aggregate(agg);
    final name = e.name.toLowerCase();
    final args = e.arguments;
    switch (name) {
      case 'if':
        final c = boolean(args[0]);
        final a = number(args[1]), b = number(args[2]);
        return (i) => c(i) == true ? a(i) : b(i);
      case 'coalesce':
        final fs = [for (final a in args) number(a)];
        return (i) {
          for (final f in fs) {
            final v = f(i);
            if (!v.isNaN) return v;
          }
          return _nan;
        };
    }
    final fn = checked.functionOf(e);
    if (fn?.implementation != null) return _customNumber(e);
    switch (name) {
      case 'abs':
        final a = number(args[0]);
        return (i) => a(i).abs();
      case 'round':
        final a = number(args[0]);
        if (args.length == 1) {
          return (i) {
            final v = a(i);
            return v.isNaN ? v : v.roundToDouble();
          };
        }
        final d = number(args[1]);
        return (i) {
          final v = a(i), digits = d(i);
          if (v.isNaN || digits.isNaN) return _nan;
          final scale = math.pow(10, digits.toInt()).toDouble();
          return (v * scale).roundToDouble() / scale;
        };
      case 'floor':
        final a = number(args[0]);
        return (i) {
          final v = a(i);
          return v.isNaN ? v : v.floorToDouble();
        };
      case 'ceil':
        final a = number(args[0]);
        return (i) {
          final v = a(i);
          return v.isNaN ? v : v.ceilToDouble();
        };
      case 'sqrt':
        final a = number(args[0]);
        return (i) {
          final v = a(i);
          return v < 0 ? _nan : math.sqrt(v);
        };
      case 'min':
      case 'max':
        final fs = [for (final a in args) number(a)];
        final isMin = name == 'min';
        return (i) {
          var best = _nan;
          for (final f in fs) {
            final v = f(i);
            if (v.isNaN) continue;
            if (best.isNaN || (isMin ? v < best : v > best)) best = v;
          }
          return best;
        };
      case 'number':
        final t = text(args[0]);
        return (i) {
          final s = t(i);
          if (s == null) return _nan;
          return double.tryParse(s.trim()) ?? _nan;
        };
      case 'len':
        final t = text(args[0]);
        return (i) {
          final s = t(i);
          return s == null ? _nan : s.length.toDouble();
        };
      case 'year':
      case 'quarter':
      case 'month':
      case 'week':
      case 'day':
      case 'weekday':
      case 'hour':
        final d = number(args[0]);
        final part = switch (name) {
          'year' => DatePart.year,
          'quarter' => DatePart.quarter,
          'month' => DatePart.month,
          'week' => DatePart.week,
          'day' => DatePart.day,
          'weekday' => DatePart.weekday,
          _ => DatePart.hour,
        };
        return (i) {
          final v = d(i);
          if (v.isNaN) return _nan;
          return datePartOf(v, part).toDouble();
        };
      case 'date':
        if (args.length == 1) {
          final t = text(args[0]);
          return (i) {
            final s = t(i);
            if (s == null) return _nan;
            final d = parseDateLiteral(s.trim());
            return d == null ? _nan : d.millisecondsSinceEpoch.toDouble();
          };
        }
        final y = number(args[0]), m = number(args[1]), d = number(args[2]);
        return (i) {
          final yv = y(i), mv = m(i), dv = d(i);
          if (yv.isNaN || mv.isNaN || dv.isNaN) return _nan;
          return DateTime.utc(
            yv.toInt(),
            mv.toInt(),
            dv.toInt(),
          ).millisecondsSinceEpoch.toDouble();
        };
      case 'today':
        final now = DateTime.now();
        final ms = DateTime.utc(
          now.year,
          now.month,
          now.day,
        ).millisecondsSinceEpoch.toDouble();
        return (_) => ms;
    }
    throw StateError('no number implementation for $name');
  }

  // --------------------------------------------------------------- text

  TextFn text(Expr e) {
    switch (e) {
      case TextLiteral(:final value):
        return (_) => value;
      case NullLiteral():
        return (_) => null;
      case NameRef(:final name):
        return bindings.text(name);
      case CallExpr():
        return _textCall(e);
      default:
        throw StateError('not text: $e');
    }
  }

  TextFn _textCall(CallExpr e) {
    final name = e.name.toLowerCase();
    final args = e.arguments;
    switch (name) {
      case 'if':
        final c = boolean(args[0]);
        final a = text(args[1]), b = text(args[2]);
        return (i) => c(i) == true ? a(i) : b(i);
      case 'coalesce':
        final fs = [for (final a in args) text(a)];
        return (i) {
          for (final f in fs) {
            final v = f(i);
            if (v != null) return v;
          }
          return null;
        };
    }
    final fn = checked.functionOf(e);
    if (fn?.implementation != null) return _customText(e);
    switch (name) {
      case 'lower':
        final t = text(args[0]);
        return (i) => t(i)?.toLowerCase();
      case 'upper':
        final t = text(args[0]);
        return (i) => t(i)?.toUpperCase();
      case 'trim':
        final t = text(args[0]);
        return (i) => t(i)?.trim();
      case 'left':
      case 'right':
        final t = text(args[0]);
        final n = number(args[1]);
        final isLeft = name == 'left';
        return (i) {
          final s = t(i);
          final count = n(i);
          if (s == null || count.isNaN) return null;
          final k = count.toInt().clamp(0, s.length);
          return isLeft ? s.substring(0, k) : s.substring(s.length - k);
        };
      case 'substring':
        final t = text(args[0]);
        final start = number(args[1]);
        final len = args.length > 2 ? number(args[2]) : null;
        return (i) {
          final s = t(i);
          final st = start(i);
          if (s == null || st.isNaN) return null;
          final from = (st.toInt() - 1).clamp(0, s.length);
          if (len == null) return s.substring(from);
          final l = len(i);
          if (l.isNaN) return null;
          final to = (from + l.toInt()).clamp(from, s.length);
          return s.substring(from, to);
        };
      case 'replace':
        final t = text(args[0]), from = text(args[1]), to = text(args[2]);
        return (i) {
          final s = t(i), f = from(i), r = to(i);
          if (s == null || f == null || r == null) return null;
          return f.isEmpty ? s : s.replaceAll(f, r);
        };
      case 'concat':
        final fs = [for (final a in args) text(a)];
        return (i) {
          final buf = StringBuffer();
          for (final f in fs) {
            final v = f(i);
            if (v != null) buf.write(v);
          }
          return buf.toString();
        };
      case 'text':
        final arg = args[0];
        switch (typeOf(arg)) {
          case ExprType.number:
            final n = number(arg);
            return (i) {
              final v = n(i);
              return v.isNaN ? null : ColumnBuilder.stringify(v);
            };
          case ExprType.date:
            final n = number(arg);
            return (i) {
              final v = n(i);
              return v.isNaN
                  ? null
                  : DateLiteral.formatDate(
                      DateTime.fromMillisecondsSinceEpoch(
                        v.toInt(),
                        isUtc: true,
                      ),
                    );
            };
          case ExprType.boolean:
            final b = boolean(arg);
            return (i) => switch (b(i)) {
              true => 'true',
              false => 'false',
              null => null,
            };
          case ExprType.text || null:
            return text(arg);
        }
    }
    throw StateError('no text implementation for $name');
  }

  // ------------------------------------------------------------ boolean

  BoolFn boolean(Expr e) {
    switch (e) {
      case BooleanLiteral(:final value):
        return (_) => value;
      case NullLiteral():
        return (_) => null;
      case NameRef(:final name):
        return bindings.boolean(name);
      case UnaryExpr(:final operand):
        final f = boolean(operand);
        return (i) {
          final v = f(i);
          return v == null ? null : !v;
        };
      case BinaryExpr(:final op, :final left, :final right):
        if (op == BinaryOp.and) {
          final a = boolean(left), b = boolean(right);
          return (i) {
            final l = a(i);
            if (l == false) return false;
            final r = b(i);
            if (r == false) return false;
            return l == null || r == null ? null : true;
          };
        }
        if (op == BinaryOp.or) {
          final a = boolean(left), b = boolean(right);
          return (i) {
            final l = a(i);
            if (l == true) return true;
            final r = b(i);
            if (r == true) return true;
            return l == null || r == null ? null : false;
          };
        }
        return _comparison(e);
      case InExpr():
        return _in(e);
      case BetweenExpr(:final subject, :final low, :final high, :final negated):
        final t = _operandType([subject, low, high]);
        final BoolFn f;
        if (t == ExprType.text) {
          final s = text(subject), lo = text(low), hi = text(high);
          f = (i) {
            final v = s(i), l = lo(i), h = hi(i);
            if (v == null || l == null || h == null) return null;
            return v.compareTo(l) >= 0 && v.compareTo(h) <= 0;
          };
        } else {
          final s = number(subject), lo = number(low), hi = number(high);
          f = (i) {
            final v = s(i), l = lo(i), h = hi(i);
            if (v.isNaN || l.isNaN || h.isNaN) return null;
            return v >= l && v <= h;
          };
        }
        return negated ? _not(f) : f;
      case IsEmptyExpr(:final subject, :final negated):
        final f = _isNull(subject);
        return negated ? (i) => !f(i) : f;
      case CallExpr():
        return _booleanCall(e);
      default:
        throw StateError('not boolean: $e');
    }
  }

  static BoolFn _not(BoolFn f) => (i) {
    final v = f(i);
    return v == null ? null : !v;
  };

  /// The type shared by [nodes] (null literals do not count), or `null`
  /// when every one is null.
  ExprType? _operandType(List<Expr> nodes) {
    for (final n in nodes) {
      final t = typeOf(n);
      if (t != null) return t;
    }
    return null;
  }

  bool Function(int) _isNull(Expr e) {
    switch (typeOf(e)) {
      case ExprType.number || ExprType.date:
        final f = number(e);
        return (i) => f(i).isNaN;
      case ExprType.text:
        final f = text(e);
        return (i) => f(i) == null;
      case ExprType.boolean:
        final f = boolean(e);
        return (i) => f(i) == null;
      case null:
        return (_) => true;
    }
  }

  BoolFn _comparison(BinaryExpr e) {
    final op = e.op;
    final left = e.left, right = e.right;
    final t = _operandType([left, right]);
    switch (t) {
      case null:
        return (_) => null;
      case ExprType.boolean:
        final a = boolean(left), b = boolean(right);
        final eq = op == BinaryOp.equal;
        return (i) {
          final l = a(i), r = b(i);
          if (l == null || r == null) return null;
          return eq ? l == r : l != r;
        };
      case ExprType.text:
        return _textComparison(op, left, right);
      case ExprType.number || ExprType.date:
        final a = number(left), b = number(right);
        return switch (op) {
          BinaryOp.equal => (i) {
            final l = a(i), r = b(i);
            return l.isNaN || r.isNaN ? null : l == r;
          },
          BinaryOp.notEqual => (i) {
            final l = a(i), r = b(i);
            return l.isNaN || r.isNaN ? null : l != r;
          },
          BinaryOp.less => (i) {
            final l = a(i), r = b(i);
            return l.isNaN || r.isNaN ? null : l < r;
          },
          BinaryOp.lessOrEqual => (i) {
            final l = a(i), r = b(i);
            return l.isNaN || r.isNaN ? null : l <= r;
          },
          BinaryOp.greater => (i) {
            final l = a(i), r = b(i);
            return l.isNaN || r.isNaN ? null : l > r;
          },
          BinaryOp.greaterOrEqual => (i) {
            final l = a(i), r = b(i);
            return l.isNaN || r.isNaN ? null : l >= r;
          },
          _ => throw StateError('not a comparison: $op'),
        };
    }
  }

  BoolFn _textComparison(BinaryOp op, Expr left, Expr right) {
    final eq = op == BinaryOp.equal || op == BinaryOp.notEqual;
    final negate = op == BinaryOp.notEqual;
    if (eq) {
      // column = literal: compare dictionary codes.
      final columnLiteral = _columnAndLiteral(left, right);
      if (columnLiteral != null) {
        final (column, literal) = columnLiteral;
        final codes = column.codes;
        final code = column.dictionary.indexOf(literal);
        return (i) {
          final c = codes[i];
          if (c < 0) return null;
          return (c == code) != negate;
        };
      }
    }
    final a = text(left), b = text(right);
    return switch (op) {
      BinaryOp.equal => (i) {
        final l = a(i), r = b(i);
        return l == null || r == null ? null : l == r;
      },
      BinaryOp.notEqual => (i) {
        final l = a(i), r = b(i);
        return l == null || r == null ? null : l != r;
      },
      BinaryOp.less => (i) {
        final l = a(i), r = b(i);
        return l == null || r == null ? null : l.compareTo(r) < 0;
      },
      BinaryOp.lessOrEqual => (i) {
        final l = a(i), r = b(i);
        return l == null || r == null ? null : l.compareTo(r) <= 0;
      },
      BinaryOp.greater => (i) {
        final l = a(i), r = b(i);
        return l == null || r == null ? null : l.compareTo(r) > 0;
      },
      BinaryOp.greaterOrEqual => (i) {
        final l = a(i), r = b(i);
        return l == null || r == null ? null : l.compareTo(r) >= 0;
      },
      _ => throw StateError('not a comparison: $op'),
    };
  }

  (TextColumn, String)? _columnAndLiteral(Expr a, Expr b) {
    if (a is NameRef && b is TextLiteral && checked.aggregateOf(a) == null) {
      final c = bindings.textColumn(a.name);
      if (c != null) return (c, b.value);
    }
    if (b is NameRef && a is TextLiteral && checked.aggregateOf(b) == null) {
      final c = bindings.textColumn(b.name);
      if (c != null) return (c, a.value);
    }
    return null;
  }

  BoolFn _in(InExpr e) {
    final subject = e.subject;
    final t = _operandType([subject, ...e.values]);
    final BoolFn f;
    switch (t) {
      case null:
        return (_) => null;
      case ExprType.text:
        final allLiterals = e.values.every((v) => v is TextLiteral);
        final column =
            subject is NameRef && checked.aggregateOf(subject) == null
            ? bindings.textColumn(subject.name)
            : null;
        if (allLiterals && column != null) {
          final wanted = <int>{
            for (final v in e.values)
              column.dictionary.indexOf((v as TextLiteral).value),
          }..remove(-1);
          final codes = column.codes;
          f = (i) {
            final c = codes[i];
            return c < 0 ? null : wanted.contains(c);
          };
        } else {
          final s = text(subject);
          final fs = [for (final v in e.values) text(v)];
          f = (i) {
            final v = s(i);
            if (v == null) return null;
            var sawNull = false;
            for (final g in fs) {
              final w = g(i);
              if (w == null) {
                sawNull = true;
              } else if (w == v) {
                return true;
              }
            }
            return sawNull ? null : false;
          };
        }
      case ExprType.boolean:
        final s = boolean(subject);
        final fs = [for (final v in e.values) boolean(v)];
        f = (i) {
          final v = s(i);
          if (v == null) return null;
          var sawNull = false;
          for (final g in fs) {
            final w = g(i);
            if (w == null) {
              sawNull = true;
            } else if (w == v) {
              return true;
            }
          }
          return sawNull ? null : false;
        };
      case ExprType.number || ExprType.date:
        final s = number(subject);
        final fs = [for (final v in e.values) number(v)];
        f = (i) {
          final v = s(i);
          if (v.isNaN) return null;
          var sawNull = false;
          for (final g in fs) {
            final w = g(i);
            if (w.isNaN) {
              sawNull = true;
            } else if (w == v) {
              return true;
            }
          }
          return sawNull ? null : false;
        };
    }
    return e.negated ? _not(f) : f;
  }

  BoolFn _booleanCall(CallExpr e) {
    final name = e.name.toLowerCase();
    final args = e.arguments;
    switch (name) {
      case 'if':
        final c = boolean(args[0]);
        final a = boolean(args[1]), b = boolean(args[2]);
        return (i) => c(i) == true ? a(i) : b(i);
      case 'coalesce':
        final fs = [for (final a in args) boolean(a)];
        return (i) {
          for (final f in fs) {
            final v = f(i);
            if (v != null) return v;
          }
          return null;
        };
      case 'isempty':
        return _isNull(args[0]);
    }
    final fn = checked.functionOf(e);
    if (fn?.implementation != null) return _customBoolean(e);
    switch (name) {
      case 'contains':
      case 'startswith':
      case 'endswith':
        final t = text(args[0]), p = text(args[1]);
        final bool Function(String, String) test = switch (name) {
          'contains' => (s, q) => s.contains(q),
          'startswith' => (s, q) => s.startsWith(q),
          _ => (s, q) => s.endsWith(q),
        };
        return (i) {
          final s = t(i), q = p(i);
          if (s == null || q == null) return null;
          return test(s, q);
        };
    }
    throw StateError('no boolean implementation for $name');
  }

  // ---------------------------------------------- application functions

  /// Boxed argument closures for a registered function.
  List<BoxedFn> _boxedArgs(CallExpr e) {
    final fn = checked.functionOf(e)!;
    return [
      for (var i = 0; i < e.arguments.length; i++)
        _boxed(e.arguments[i], typeOf(e.arguments[i]) ?? fn.parameterAt(i)!),
    ];
  }

  BoxedFn _boxed(Expr e, ExprType t) {
    switch (t) {
      case ExprType.number:
        final f = number(e);
        return (i) {
          final v = f(i);
          return v.isNaN ? null : v;
        };
      case ExprType.date:
        final f = number(e);
        return (i) {
          final v = f(i);
          return v.isNaN
              ? null
              : DateTime.fromMillisecondsSinceEpoch(v.toInt(), isUtc: true);
        };
      case ExprType.text:
        return text(e);
      case ExprType.boolean:
        return boolean(e);
    }
  }

  BoxedFn _customCall(CallExpr e) {
    final impl = checked.functionOf(e)!.implementation!;
    final args = _boxedArgs(e);
    final n = args.length;
    return (i) {
      final values = List<Object?>.filled(n, null);
      for (var k = 0; k < n; k++) {
        values[k] = args[k](i);
      }
      return impl(values);
    };
  }

  NumberFn _customNumber(CallExpr e) {
    final f = _customCall(e);
    return typeOf(e) == ExprType.date
        ? (i) {
            final v = f(i);
            return v is DateTime ? v.millisecondsSinceEpoch.toDouble() : _nan;
          }
        : (i) {
            final v = f(i);
            return v is num ? v.toDouble() : _nan;
          };
  }

  TextFn _customText(CallExpr e) {
    final f = _customCall(e);
    return (i) {
      final v = f(i);
      return v is String ? v : null;
    };
  }

  BoolFn _customBoolean(CallExpr e) {
    final f = _customCall(e);
    return (i) {
      final v = f(i);
      return v is bool ? v : null;
    };
  }
}

/// The calendar [part] of a date given as UTC milliseconds (same values as
/// [DatePartDimension]).
int datePartOf(double millis, DatePart part) {
  final d = DateTime.fromMillisecondsSinceEpoch(millis.toInt(), isUtc: true);
  return switch (part) {
    DatePart.year => d.year,
    DatePart.quarter => (d.month - 1) ~/ 3 + 1,
    DatePart.month => d.month,
    DatePart.week => isoWeek(d),
    DatePart.day => d.day,
    DatePart.weekday => d.weekday,
    DatePart.hour => d.hour,
  };
}
