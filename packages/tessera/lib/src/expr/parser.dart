import 'ast.dart';
import 'expression_error.dart';

// A hand-written lexer and Pratt parser for the expression grammar:
//
//   expr        = or
//   or          = and ("or" and)*
//   and         = not ("and" not)*
//   not         = "not" not | comparison
//   comparison  = additive (compOp additive)?
//               | additive ["not"] "in" "(" expr ("," expr)* ")"
//               | additive ["not"] "between" additive "and" additive
//               | additive "is" ["not"] ("empty" | "null")
//   compOp      = "=" | "==" | "<>" | "!=" | "<" | "<=" | ">" | ">="
//   additive    = multiplicative (("+" | "-") multiplicative)*
//   multiplicative = unary (("*" | "/" | "%") unary)*
//   unary       = "-" unary | "+" unary | primary
//   primary     = number | text | date | "true" | "false" | "null"
//               | name "(" [expr ("," expr)*] ")" | name | "(" expr ")"
//
// Keywords and function names are case-insensitive; column names are not.

enum _T { number, text, date, name, keyword, symbol, end }

final class _Token {
  _Token(this.type, this.offset, this.length, this.text, [this.value]);
  final _T type;
  final int offset;
  final int length;

  /// Keyword/symbol text in lower case, or the raw name.
  final String text;

  /// Number, String or DateTime for literals.
  final Object? value;
  int get end => offset + length;
}

ExpressionError _error(
  ExpressionErrorKind kind,
  int offset,
  int length, [
  List<String> args = const [],
]) => ExpressionError(kind, offset: offset, length: length, arguments: args);

final class _Lexer {
  _Lexer(this.src);
  final String src;
  int pos = 0;

  static const _symbols = [
    '<=',
    '>=',
    '<>',
    '!=',
    '==',
    '=',
    '<',
    '>',
    '+',
    '-',
    '*',
    '/',
    '%',
    '(',
    ')',
    ',',
  ];

  List<_Token> tokenize() {
    final out = <_Token>[];
    while (true) {
      final t = _next();
      out.add(t);
      if (t.type == _T.end) return out;
    }
  }

  static bool _isDigit(int c) => c >= 0x30 && c <= 0x39;
  static bool _isNameStart(int c) =>
      (c >= 0x41 && c <= 0x5a) ||
      (c >= 0x61 && c <= 0x7a) ||
      c == 0x5f ||
      c > 0x7f;
  static bool _isNamePart(int c) => _isNameStart(c) || _isDigit(c);
  static bool _isSpace(int c) =>
      c == 0x20 || c == 0x09 || c == 0x0a || c == 0x0d;

  _Token _next() {
    while (pos < src.length && _isSpace(src.codeUnitAt(pos))) {
      pos++;
    }
    if (pos >= src.length) return _Token(_T.end, pos, 0, '');
    final start = pos;
    final c = src.codeUnitAt(pos);
    if (_isDigit(c) ||
        (c == 0x2e &&
            pos + 1 < src.length &&
            _isDigit(src.codeUnitAt(pos + 1)))) {
      return _number(start);
    }
    if (c == 0x22 || c == 0x27) return _text(start, c);
    if (c == 0x23) return _date(start);
    if (c == 0x5b) return _quotedName(start);
    if (_isNameStart(c)) {
      while (pos < src.length && _isNamePart(src.codeUnitAt(pos))) {
        pos++;
      }
      final word = src.substring(start, pos);
      final lower = word.toLowerCase();
      if (expressionKeywords.contains(lower)) {
        return _Token(_T.keyword, start, pos - start, lower);
      }
      return _Token(_T.name, start, pos - start, word);
    }
    for (final s in _symbols) {
      if (src.startsWith(s, pos)) {
        pos += s.length;
        return _Token(_T.symbol, start, s.length, s);
      }
    }
    throw _error(ExpressionErrorKind.unexpectedCharacter, start, 1, [
      src[start],
    ]);
  }

  _Token _number(int start) {
    while (pos < src.length && _isDigit(src.codeUnitAt(pos))) {
      pos++;
    }
    if (pos < src.length && src.codeUnitAt(pos) == 0x2e) {
      pos++;
      while (pos < src.length && _isDigit(src.codeUnitAt(pos))) {
        pos++;
      }
    }
    if (pos < src.length && (src.codeUnitAt(pos) | 0x20) == 0x65) {
      var p = pos + 1;
      if (p < src.length &&
          (src.codeUnitAt(p) == 0x2b || src.codeUnitAt(p) == 0x2d)) {
        p++;
      }
      if (p < src.length && _isDigit(src.codeUnitAt(p))) {
        pos = p;
        while (pos < src.length && _isDigit(src.codeUnitAt(pos))) {
          pos++;
        }
      }
    }
    // A number directly followed by a name character is a typo (1abc).
    if (pos < src.length && _isNamePart(src.codeUnitAt(pos))) {
      while (pos < src.length && _isNamePart(src.codeUnitAt(pos))) {
        pos++;
      }
      throw _error(ExpressionErrorKind.invalidNumber, start, pos - start, [
        src.substring(start, pos),
      ]);
    }
    final text = src.substring(start, pos);
    final v = double.tryParse(text);
    if (v == null) {
      throw _error(ExpressionErrorKind.invalidNumber, start, pos - start, [
        text,
      ]);
    }
    return _Token(_T.number, start, pos - start, text, v);
  }

  _Token _text(int start, int quote) {
    final buf = StringBuffer();
    pos++;
    while (true) {
      if (pos >= src.length) {
        throw _error(ExpressionErrorKind.unterminatedText, start, pos - start);
      }
      final c = src.codeUnitAt(pos);
      if (c == quote) {
        if (pos + 1 < src.length && src.codeUnitAt(pos + 1) == quote) {
          buf.writeCharCode(quote);
          pos += 2;
          continue;
        }
        pos++;
        break;
      }
      buf.writeCharCode(c);
      pos++;
    }
    return _Token(
      _T.text,
      start,
      pos - start,
      src.substring(start, pos),
      buf.toString(),
    );
  }

  _Token _quotedName(int start) {
    final buf = StringBuffer();
    pos++;
    while (true) {
      if (pos >= src.length) {
        throw _error(ExpressionErrorKind.unterminatedName, start, pos - start);
      }
      final c = src.codeUnitAt(pos);
      if (c == 0x5d) {
        if (pos + 1 < src.length && src.codeUnitAt(pos + 1) == 0x5d) {
          buf.write(']');
          pos += 2;
          continue;
        }
        pos++;
        break;
      }
      buf.writeCharCode(c);
      pos++;
    }
    return _Token(_T.name, start, pos - start, buf.toString());
  }

  _Token _date(int start) {
    pos++;
    final close = src.indexOf('#', pos);
    if (close < 0) {
      pos = src.length;
      throw _error(ExpressionErrorKind.unterminatedDate, start, pos - start);
    }
    final text = src.substring(pos, close).trim();
    pos = close + 1;
    final value = parseDateLiteral(text);
    if (value == null) {
      throw _error(ExpressionErrorKind.invalidDate, start, pos - start, [text]);
    }
    return _Token(
      _T.date,
      start,
      pos - start,
      src.substring(start, pos),
      value,
    );
  }
}

final _dateLiteral = RegExp(
  r'^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2})(?::(\d{2})(?:\.(\d{1,3}))?)?)?$',
);

/// Parses the inside of a `#…#` literal: `yyyy-MM-dd`, optionally followed
/// by ` HH:mm`, `:ss` and `.SSS` (a `T` separator is accepted too). The
/// result is UTC, like every date in a fact table. `null` when malformed.
DateTime? parseDateLiteral(String text) {
  final m = _dateLiteral.firstMatch(text);
  if (m == null) return null;
  int part(int i) => int.parse(m.group(i)!);
  final ms = m.group(7);
  final d = DateTime.utc(
    part(1),
    part(2),
    part(3),
    m.group(4) == null ? 0 : part(4),
    m.group(5) == null ? 0 : part(5),
    m.group(6) == null ? 0 : part(6),
    ms == null ? 0 : int.parse(ms.padRight(3, '0')),
  );
  // Reject 2024-02-30 (DateTime.utc would roll over).
  if (d.month != part(2) || d.day != part(3)) return null;
  return d;
}

/// Parses [source] into an [Expr] tree. Throws [ExpressionError].
Expr parseExpression(String source) => _Parser(source).parse();

final class _Parser {
  _Parser(this.src) : tokens = _Lexer(src).tokenize();

  final String src;
  final List<_Token> tokens;
  int i = 0;

  _Token get peek => tokens[i];
  _Token get previous => tokens[i - 1];

  _Token advance() => tokens[i++];

  bool _isKeyword(String k) => peek.type == _T.keyword && peek.text == k;
  bool _isSymbol(String s) => peek.type == _T.symbol && peek.text == s;
  bool _nextIsKeyword(String k) =>
      i + 1 < tokens.length &&
      tokens[i + 1].type == _T.keyword &&
      tokens[i + 1].text == k;

  Never _unexpected() {
    final t = peek;
    if (t.type == _T.end) {
      throw _error(ExpressionErrorKind.unexpectedEnd, t.offset, 0);
    }
    throw _error(ExpressionErrorKind.unexpectedToken, t.offset, t.length, [
      src.substring(t.offset, t.end),
    ]);
  }

  _Token expectSymbol(String s) {
    if (!_isSymbol(s)) _unexpected();
    return advance();
  }

  _Token expectKeyword(String k) {
    if (!_isKeyword(k)) _unexpected();
    return advance();
  }

  Expr parse() {
    final e = _or();
    if (peek.type != _T.end) _unexpected();
    return e;
  }

  Expr _or() {
    var left = _and();
    while (_isKeyword('or')) {
      advance();
      final right = _and();
      left = BinaryExpr(
        BinaryOp.or,
        left,
        right,
        offset: left.offset,
        length: right.end - left.offset,
      );
    }
    return left;
  }

  Expr _and() {
    var left = _not();
    while (_isKeyword('and')) {
      advance();
      final right = _not();
      left = BinaryExpr(
        BinaryOp.and,
        left,
        right,
        offset: left.offset,
        length: right.end - left.offset,
      );
    }
    return left;
  }

  Expr _not() {
    if (_isKeyword('not')) {
      final t = advance();
      final operand = _not();
      return UnaryExpr(
        UnaryOp.not,
        operand,
        offset: t.offset,
        length: operand.end - t.offset,
      );
    }
    return _comparison();
  }

  static const _compOps = {
    '=': BinaryOp.equal,
    '==': BinaryOp.equal,
    '<>': BinaryOp.notEqual,
    '!=': BinaryOp.notEqual,
    '<': BinaryOp.less,
    '<=': BinaryOp.lessOrEqual,
    '>': BinaryOp.greater,
    '>=': BinaryOp.greaterOrEqual,
  };

  Expr _comparison() {
    final left = _additive();
    if (peek.type == _T.symbol) {
      final op = _compOps[peek.text];
      if (op != null) {
        advance();
        final right = _additive();
        return BinaryExpr(
          op,
          left,
          right,
          offset: left.offset,
          length: right.end - left.offset,
        );
      }
      return left;
    }
    if (peek.type != _T.keyword) return left;
    var negated = false;
    if (_isKeyword('not') &&
        (_nextIsKeyword('in') || _nextIsKeyword('between'))) {
      advance();
      negated = true;
    }
    if (_isKeyword('in')) {
      advance();
      expectSymbol('(');
      final values = <Expr>[];
      if (!_isSymbol(')')) {
        values.add(_or());
        while (_isSymbol(',')) {
          advance();
          values.add(_or());
        }
      }
      final close = expectSymbol(')');
      return InExpr(
        left,
        values,
        negated: negated,
        offset: left.offset,
        length: close.end - left.offset,
      );
    }
    if (_isKeyword('between')) {
      advance();
      final low = _additive();
      expectKeyword('and');
      final high = _additive();
      return BetweenExpr(
        left,
        low,
        high,
        negated: negated,
        offset: left.offset,
        length: high.end - left.offset,
      );
    }
    if (_isKeyword('is')) {
      advance();
      var neg = false;
      if (_isKeyword('not')) {
        advance();
        neg = true;
      }
      if (!_isKeyword('empty') && !_isKeyword('null')) _unexpected();
      final last = advance();
      return IsEmptyExpr(
        left,
        negated: neg,
        offset: left.offset,
        length: last.end - left.offset,
      );
    }
    return left;
  }

  Expr _additive() {
    var left = _multiplicative();
    while (peek.type == _T.symbol && (peek.text == '+' || peek.text == '-')) {
      final op = advance().text == '+' ? BinaryOp.add : BinaryOp.subtract;
      final right = _multiplicative();
      left = BinaryExpr(
        op,
        left,
        right,
        offset: left.offset,
        length: right.end - left.offset,
      );
    }
    return left;
  }

  Expr _multiplicative() {
    var left = _unary();
    while (peek.type == _T.symbol &&
        (peek.text == '*' || peek.text == '/' || peek.text == '%')) {
      final op = switch (advance().text) {
        '*' => BinaryOp.multiply,
        '/' => BinaryOp.divide,
        _ => BinaryOp.modulo,
      };
      final right = _unary();
      left = BinaryExpr(
        op,
        left,
        right,
        offset: left.offset,
        length: right.end - left.offset,
      );
    }
    return left;
  }

  Expr _unary() {
    if (_isSymbol('-')) {
      final t = advance();
      final operand = _unary();
      // Fold the sign into a literal so `-1` is one node.
      if (operand is NumberLiteral) {
        return NumberLiteral(
          -operand.value,
          offset: t.offset,
          length: operand.end - t.offset,
        );
      }
      return UnaryExpr(
        UnaryOp.negate,
        operand,
        offset: t.offset,
        length: operand.end - t.offset,
      );
    }
    if (_isSymbol('+')) {
      advance();
      return _unary();
    }
    return _primary();
  }

  Expr _primary() {
    final t = peek;
    switch (t.type) {
      case _T.number:
        advance();
        return NumberLiteral(
          t.value as double,
          offset: t.offset,
          length: t.length,
        );
      case _T.text:
        advance();
        return TextLiteral(
          t.value as String,
          offset: t.offset,
          length: t.length,
        );
      case _T.date:
        advance();
        return DateLiteral(
          t.value as DateTime,
          offset: t.offset,
          length: t.length,
        );
      case _T.keyword:
        switch (t.text) {
          case 'true':
            advance();
            return BooleanLiteral(true, offset: t.offset, length: t.length);
          case 'false':
            advance();
            return BooleanLiteral(false, offset: t.offset, length: t.length);
          case 'null':
            advance();
            return NullLiteral(offset: t.offset, length: t.length);
        }
        _unexpected();
      case _T.name:
        advance();
        if (_isSymbol('(')) {
          advance();
          final args = <Expr>[];
          if (!_isSymbol(')')) {
            args.add(_or());
            while (_isSymbol(',')) {
              advance();
              args.add(_or());
            }
          }
          final close = expectSymbol(')');
          return CallExpr(
            t.text,
            args,
            nameLength: t.length,
            offset: t.offset,
            length: close.end - t.offset,
          );
        }
        return NameRef(t.text, offset: t.offset, length: t.length);
      case _T.symbol:
        if (t.text == '(') {
          advance();
          final inner = _or();
          expectSymbol(')');
          return inner;
        }
        _unexpected();
      case _T.end:
        _unexpected();
    }
  }
}
