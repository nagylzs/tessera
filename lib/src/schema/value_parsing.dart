/// How numbers are written in a source: decimal and thousands separators.
///
/// Thousands separators are only accepted in proper groups of three
/// (`1,234,567`), so `12,3` is *not* read as `123` — it fails to parse and
/// the column falls back to text.
final class NumberSyntax {
  const NumberSyntax({
    this.decimalSeparator = '.',
    this.thousandsSeparators = const {','},
  });

  /// `1,234.56`
  static const standard = NumberSyntax();

  /// `1.234,56`, `1 234,56` (space or non-breaking space).
  static const european = NumberSyntax(
    decimalSeparator: ',',
    thousandsSeparators: {'.', ' ', ' '},
  );

  final String decimalSeparator;
  final Set<String> thousandsSeparators;

  static final _digits = RegExp(r'^[+-]?\d+$');
  static final _decimal = RegExp(r'^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$');

  /// Parses a whole number, or `null` if [raw] is not one.
  int? parseInteger(String raw) {
    final s = _normalize(raw);
    if (s == null || !_digits.hasMatch(s)) return null;
    return int.tryParse(s);
  }

  /// Parses a real number, or `null` if [raw] is not one. Infinity and NaN
  /// are rejected.
  double? parseNumber(String raw) {
    final s = _normalize(raw);
    if (s == null || !_decimal.hasMatch(s)) return null;
    final v = double.tryParse(s);
    return v != null && v.isFinite ? v : null;
  }

  /// Strips grouping separators and converts the decimal separator to `.`.
  /// Returns `null` for malformed grouping or more than one decimal point.
  String? _normalize(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    final dot = s.indexOf(decimalSeparator);
    if (dot != -1 && s.indexOf(decimalSeparator, dot + 1) != -1) return null;
    var intPart = dot == -1 ? s : s.substring(0, dot);
    final fracPart = dot == -1 ? '' : s.substring(dot + 1);
    for (final sep in thousandsSeparators) {
      if (!intPart.contains(sep)) continue;
      final groups = intPart.split(sep);
      final first = groups.first.replaceFirst(RegExp(r'^[+-]'), '');
      if (first.isEmpty || first.length > 3) return null;
      if (groups.skip(1).any((g) => g.length != 3)) return null;
      intPart = groups.join();
    }
    return dot == -1 ? intPart : '$intPart.$fracPart';
  }

  @override
  bool operator ==(Object other) =>
      other is NumberSyntax &&
      other.decimalSeparator == decimalSeparator &&
      other.thousandsSeparators.length == thousandsSeparators.length &&
      other.thousandsSeparators.containsAll(thousandsSeparators);

  @override
  int get hashCode => Object.hash(
    decimalSeparator,
    Object.hashAllUnordered(thousandsSeparators),
  );
}

/// Parses `true`/`false`/`yes`/`no` (case-insensitive), or `null`.
///
/// `1`/`0` are deliberately not booleans: a column of them is an integer
/// column, which can be summed.
bool? parseBoolean(String raw) => switch (raw.trim().toLowerCase()) {
  'true' || 'yes' => true,
  'false' || 'no' => false,
  _ => null,
};

/// Date patterns tried by default, in order, when a schema has no explicit
/// [ColumnSpec.format].
const defaultDateFormats = [
  'yyyy-MM-dd',
  'yyyy-MM-ddTHH:mm:ss',
  'yyyy-MM-dd HH:mm:ss',
  'yyyy-MM-dd HH:mm',
];

/// A compiled date/time pattern such as `yyyy-MM-dd` or `dd.MM.yyyy HH:mm`.
///
/// Supported tokens: `yyyy`, `yy` (→ 20yy), `MM`/`M`, `dd`/`d`, `HH`/`H`,
/// `mm`/`m`, `ss`/`s`, `SSS` (milliseconds). A doubled token requires
/// exactly that many digits, a single one accepts one or two. Every other
/// character is a literal that must match. Time zones are not supported;
/// results are always UTC.
final class DatePattern {
  DatePattern._(this.pattern, this._tokens)
    : hasTime = _tokens.any(
        (t) => t is _Field && const {'H', 'm', 's', 'S'}.contains(t.letter),
      );

  /// Compiles (and caches) [pattern].
  factory DatePattern.of(String pattern) => _cache.putIfAbsent(
    pattern,
    () => DatePattern._(pattern, _tokenize(pattern)),
  );

  static final _cache = <String, DatePattern>{};
  static const _letters = {'y', 'M', 'd', 'H', 'm', 's', 'S'};

  final String pattern;
  final List<_Token> _tokens;

  /// Whether the pattern contains any time-of-day field.
  final bool hasTime;

  static List<_Token> _tokenize(String pattern) {
    final tokens = <_Token>[];
    final literal = StringBuffer();
    var i = 0;
    while (i < pattern.length) {
      final ch = pattern[i];
      if (_letters.contains(ch)) {
        if (literal.isNotEmpty) {
          tokens.add(_Literal(literal.toString()));
          literal.clear();
        }
        var n = 1;
        while (i + n < pattern.length && pattern[i + n] == ch) {
          n++;
        }
        tokens.add(_Field(ch, n));
        i += n;
      } else {
        literal.write(ch);
        i++;
      }
    }
    if (literal.isNotEmpty) tokens.add(_Literal(literal.toString()));
    return tokens;
  }

  /// Parses [raw] (trimmed) against the pattern; `null` on any mismatch or
  /// impossible date such as `2025-02-30`.
  DateTime? parse(String raw) {
    final s = raw.trim();
    var pos = 0;
    var year = 1, month = 1, day = 1, hour = 0, minute = 0, second = 0, ms = 0;
    for (final token in _tokens) {
      switch (token) {
        case _Literal(:final text):
          if (!s.startsWith(text, pos)) return null;
          pos += text.length;
        case _Field(:final letter, :final count):
          final (min, max) = switch (letter) {
            'y' => count >= 4 ? (4, 4) : (2, 2),
            'S' => (1, 3),
            _ => count == 1 ? (1, 2) : (count, count),
          };
          var end = pos;
          while (end < s.length &&
              end - pos < max &&
              _isDigit(s.codeUnitAt(end))) {
            end++;
          }
          if (end - pos < min) return null;
          final digits = end - pos;
          final value = int.parse(s.substring(pos, end));
          pos = end;
          switch (letter) {
            case 'y':
              year = count >= 4 ? value : 2000 + value;
            case 'M':
              month = value;
            case 'd':
              day = value;
            case 'H':
              hour = value;
            case 'm':
              minute = value;
            case 's':
              second = value;
            case 'S':
              ms =
                  value *
                  (digits == 1
                      ? 100
                      : digits == 2
                      ? 10
                      : 1);
          }
      }
    }
    if (pos != s.length) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    if (hour > 23 || minute > 59 || second > 59) return null;
    final result = DateTime.utc(year, month, day, hour, minute, second, ms);
    // Reject rollovers such as February 30th.
    if (result.month != month || result.day != day) return null;
    return result;
  }

  static bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

  @override
  String toString() => 'DatePattern($pattern)';
}

sealed class _Token {
  const _Token();
}

final class _Literal extends _Token {
  const _Literal(this.text);
  final String text;
}

final class _Field extends _Token {
  const _Field(this.letter, this.count);
  final String letter;
  final int count;
}
