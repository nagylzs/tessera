import 'package:flutter/material.dart';
import 'package:tessera/tessera.dart';

import '../l10n/tessera_localizations.dart';
import 'expression_help.dart';

/// What an [ExpressionField] reports: the text and its first error, if
/// any, in [scope].
final class ExpressionFieldValue {
  const ExpressionFieldValue(this.source, this.error);

  final String source;
  final ExpressionError? error;

  bool get isValid => error == null;
}

/// A text field for an expression of the expression language: validated
/// on every keystroke in [scope] (and, with [expected], as an expression
/// of that type), the error's source range underlined and its message
/// shown in the current language.
///
/// With [help] (the default) a ? button at its end opens
/// [showExpressionHelp]; what is tapped there goes in at the cursor.
/// [columnLabels] (column name → label) shows there what the columns are
/// called elsewhere in the app.
class ExpressionField extends StatefulWidget {
  const ExpressionField({
    super.key,
    required this.scope,
    required this.onChanged,
    this.initialValue = '',
    this.expected,
    this.label,
    this.hintText,
    this.autofocus = false,
    this.help = true,
    this.columnLabels = const {},
  });

  final ExpressionScope scope;
  final ExprType? expected;
  final String initialValue;
  final ValueChanged<ExpressionFieldValue> onChanged;

  /// Defaults to the localized "Expression".
  final String? label;
  final String? hintText;
  final bool autofocus;

  /// Whether the field offers the expression help.
  final bool help;
  final Map<String, String> columnLabels;

  /// The first error of [source] in [scope], or `null` when valid.
  static ExpressionError? validate(
    String source,
    ExpressionScope scope, {
    ExprType? expected,
  }) => Expression.validate(source, scope: scope, expected: expected);

  @override
  State<ExpressionField> createState() => _ExpressionFieldState();
}

class _ExpressionFieldState extends State<ExpressionField> {
  late final _controller = ExpressionTextController(text: widget.initialValue);
  final _focus = FocusNode();
  ExpressionError? _error;

  @override
  void initState() {
    super.initState();
    _error = ExpressionField.validate(
      widget.initialValue,
      widget.scope,
      expected: widget.expected,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _changed(String text) {
    setState(() {
      _error = ExpressionField.validate(
        text,
        widget.scope,
        expected: widget.expected,
      );
    });
    widget.onChanged(ExpressionFieldValue(text, _error));
  }

  Future<void> _openHelp() async {
    final snippet = await showExpressionHelp(
      context,
      scope: widget.scope,
      expected: widget.expected,
      columnLabels: widget.columnLabels,
    );
    if (snippet == null || !mounted) return;
    _controller.value = snippet.insertInto(_controller.value);
    _changed(_controller.text);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final strings = TesseraLocalizations.of(context);
    _controller.error = _error;
    return TextField(
      controller: _controller,
      focusNode: _focus,
      autofocus: widget.autofocus,
      style: const TextStyle(fontFamily: 'monospace'),
      decoration: InputDecoration(
        isDense: true,
        labelText: widget.label ?? strings.expression,
        hintText: widget.hintText,
        // An empty field is invalid but not yet wrong: no message until
        // the user has typed something.
        errorText: _error == null || _controller.text.isEmpty
            ? null
            : strings.expressionError(_error!),
        errorMaxLines: 3,
        suffixIcon: widget.help
            ? IconButton(
                icon: const Icon(Icons.help_outline),
                tooltip: strings.expressionHelp.title,
                visualDensity: VisualDensity.compact,
                onPressed: _openHelp,
              )
            : null,
      ),
      onChanged: _changed,
    );
  }
}

/// A [TextEditingController] that renders the source range of an
/// [ExpressionError] with a wavy red underline, the way code editors mark
/// a problem. Set [error] before each build.
class ExpressionTextController extends TextEditingController {
  ExpressionTextController({super.text});

  ExpressionError? error;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final e = error;
    final t = text;
    if (e == null || e.length == 0 || e.offset >= t.length) {
      return TextSpan(text: t, style: style);
    }
    final end = (e.offset + e.length).clamp(0, t.length);
    final color = Theme.of(context).colorScheme.error;
    return TextSpan(
      style: style,
      children: [
        TextSpan(text: t.substring(0, e.offset)),
        TextSpan(
          text: t.substring(e.offset, end),
          style: TextStyle(
            decoration: TextDecoration.underline,
            decorationColor: color,
            decorationStyle: TextDecorationStyle.wavy,
            backgroundColor: color.withValues(alpha: 0.12),
          ),
        ),
        TextSpan(text: t.substring(end)),
      ],
    );
  }
}
