/// What went wrong in an expression; the message is composed from the kind
/// and [ExpressionError.arguments] so it can be localized.
enum ExpressionErrorKind {
  /// A character that cannot start a token. Argument: the character.
  unexpectedCharacter,

  /// A `"…"` or `'…'` literal without a closing quote.
  unterminatedText,

  /// A `[…]` column name without a closing bracket.
  unterminatedName,

  /// A `#…#` date literal without a closing `#`.
  unterminatedDate,

  /// A number literal that does not parse. Argument: the text.
  invalidNumber,

  /// A date literal that does not parse. Argument: the text.
  invalidDate,

  /// A token that does not fit here. Argument: the token text.
  unexpectedToken,

  /// The expression ends where more was expected.
  unexpectedEnd,

  /// A column name that is not in the schema. Argument: the name.
  unknownColumn,

  /// A function name that is not registered. Argument: the name.
  unknownFunction,

  /// A function called with the wrong number of arguments. Arguments: the
  /// name, the expected count (or range), the actual count.
  argumentCount,

  /// An argument of the wrong type. Arguments: the function name, the
  /// 1-based argument index, the expected type, the actual type.
  argumentType,

  /// An operand of the wrong type. Arguments: the operator, the expected
  /// type(s), the actual type.
  operandType,

  /// Two operands whose types do not go together. Arguments: the operator,
  /// the left type, the right type.
  incompatibleTypes,

  /// The type of the expression cannot be determined (every branch is
  /// `null`).
  unknownType,

  /// A column reference where only aggregates are allowed (in a cell
  /// formula) or an aggregate where only columns are allowed. Argument: the
  /// name.
  notAllowedHere,

  /// The expression's type is not the one required. Arguments: the
  /// expected type, the actual type.
  resultType,
}

/// A parse or type error in an expression, with the source range it refers
/// to so an editor can highlight it.
///
/// [message] is English; a localized text can be composed from [kind] and
/// [arguments].
final class ExpressionError implements Exception {
  const ExpressionError(
    this.kind, {
    required this.offset,
    required this.length,
    this.arguments = const [],
  });

  final ExpressionErrorKind kind;

  /// Start of the offending text in the source, in UTF-16 code units.
  final int offset;

  /// Length of the offending text; `0` at the end of the source.
  final int length;

  /// Kind-specific details, see [ExpressionErrorKind].
  final List<String> arguments;

  String get message {
    final a = arguments;
    return switch (kind) {
      ExpressionErrorKind.unexpectedCharacter =>
        'unexpected character "${a[0]}"',
      ExpressionErrorKind.unterminatedText => 'unterminated text literal',
      ExpressionErrorKind.unterminatedName => 'missing "]" after column name',
      ExpressionErrorKind.unterminatedDate => 'missing "#" after date',
      ExpressionErrorKind.invalidNumber => 'invalid number "${a[0]}"',
      ExpressionErrorKind.invalidDate => 'invalid date "${a[0]}"',
      ExpressionErrorKind.unexpectedToken => 'unexpected "${a[0]}"',
      ExpressionErrorKind.unexpectedEnd => 'unexpected end of expression',
      ExpressionErrorKind.unknownColumn => 'unknown column "${a[0]}"',
      ExpressionErrorKind.unknownFunction => 'unknown function "${a[0]}"',
      ExpressionErrorKind.argumentCount =>
        '${a[0]} expects ${a[1]} argument(s), got ${a[2]}',
      ExpressionErrorKind.argumentType =>
        'argument ${a[1]} of ${a[0]} must be ${a[2]}, not ${a[3]}',
      ExpressionErrorKind.operandType =>
        'operand of ${a[0]} must be ${a[1]}, not ${a[2]}',
      ExpressionErrorKind.incompatibleTypes =>
        'cannot apply ${a[0]} to ${a[1]} and ${a[2]}',
      ExpressionErrorKind.unknownType => 'cannot determine the type',
      ExpressionErrorKind.notAllowedHere => '"${a[0]}" is not allowed here',
      ExpressionErrorKind.resultType =>
        'the expression must be ${a[0]}, not ${a[1]}',
    };
  }

  @override
  String toString() => 'ExpressionError($message at $offset)';
}
