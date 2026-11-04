import 'package:flutter/material.dart';
import 'package:tessera/tessera.dart';

import '../l10n/tessera_localizations.dart';
import 'picker_frame.dart';

/// What the expression help hands back when an entry is tapped: [text]
/// to insert at the cursor, after which the cursor stands at [cursor]
/// within it (inside the parentheses of `round()`).
final class ExpressionSnippet {
  const ExpressionSnippet(this.text, {int? cursor})
    : cursor = cursor ?? text.length;

  /// A call of [name]: `name()`, the cursor between the parentheses when
  /// the function takes arguments.
  factory ExpressionSnippet.call(String name, {bool hasParameters = true}) =>
      ExpressionSnippet(
        '$name()',
        cursor: hasParameters ? name.length + 1 : null,
      );

  final String text;
  final int cursor;

  /// [value] with [text] put over its selection (at the end when it has
  /// none) and the cursor moved to [cursor]. A space goes in front when
  /// the text would otherwise run into a name or number before it.
  TextEditingValue insertInto(TextEditingValue value) {
    final old = value.text;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : old.length;
    final end = selection.isValid ? selection.end : old.length;
    final space =
        start > 0 &&
            text.isNotEmpty &&
            _joins.hasMatch(old[start - 1]) &&
            _joins.hasMatch(text[0])
        ? ' '
        : '';
    return TextEditingValue(
      text: old.replaceRange(start, end, '$space$text'),
      selection: TextSelection.collapsed(offset: start + space.length + cursor),
    );
  }

  /// Characters that would merge with a name typed next to them.
  static final _joins = RegExp(r'[\p{L}\p{N}_\]\[]', unicode: true);

  @override
  bool operator ==(Object other) =>
      other is ExpressionSnippet &&
      other.text == text &&
      other.cursor == cursor;

  @override
  int get hashCode => Object.hash(text, cursor);

  @override
  String toString() => 'ExpressionSnippet($text, $cursor)';
}

/// Shows the expression help for an expression in [scope], checked as
/// [expected], and returns the entry tapped, or `null` when closed.
///
/// The help explains what the expression does in its place (a filter, a
/// calculated measure, a computed dimension or a cell formula, told from
/// [scope] and [expected]), gives examples over the scope's own columns,
/// lists the columns ([columnLabels] adds the label of a column whose
/// name differs from it) or the aggregates of a cell formula, the
/// operators, how values are written, the rules for empty values, and
/// every function, those an application adds included. With [insert]
/// false nothing can be tapped and the result is always `null`.
///
/// On a phone, or wherever the screen is narrow or short, the help takes
/// the whole screen. Texts come from [TesseraStrings.expressionHelp].
Future<ExpressionSnippet?> showExpressionHelp(
  BuildContext context, {
  required ExpressionScope scope,
  ExprType? expected,
  Map<String, String> columnLabels = const {},
  bool insert = true,
}) => showDialog<ExpressionSnippet>(
  context: context,
  builder: (context) => ExpressionHelpDialog(
    scope: scope,
    expected: expected,
    columnLabels: columnLabels,
    insert: insert,
  ),
);

/// The dialog behind [showExpressionHelp]; pops with the
/// [ExpressionSnippet] tapped.
class ExpressionHelpDialog extends StatelessWidget {
  const ExpressionHelpDialog({
    super.key,
    required this.scope,
    this.expected,
    this.columnLabels = const {},
    this.insert = true,
  });

  final ExpressionScope scope;
  final ExprType? expected;
  final Map<String, String> columnLabels;
  final bool insert;

  @override
  Widget build(BuildContext context) {
    final help = TesseraLocalizations.of(context).expressionHelp;
    final content = ExpressionHelp(
      scope: scope,
      expected: expected,
      columnLabels: columnLabels,
      onPick: insert ? (s) => Navigator.pop(context, s) : null,
    );
    if (MediaQuery.sizeOf(context).width < 600 || isShortScreen(context)) {
      return FullScreenPicker(title: help.title, body: content);
    }
    final theme = Theme.of(context);
    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(help.title, style: theme.textTheme.titleLarge),
                  ),
                  const CloseButton(),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(child: content),
          ],
        ),
      ),
    );
  }
}

/// The content of the expression help (see [showExpressionHelp]) as a
/// scrolling list, for an app that shows it on its own page. Entries can
/// be tapped when [onPick] is given.
class ExpressionHelp extends StatelessWidget {
  const ExpressionHelp({
    super.key,
    required this.scope,
    this.expected,
    this.columnLabels = const {},
    this.onPick,
    this.padding = const EdgeInsets.fromLTRB(24, 16, 24, 24),
  });

  final ExpressionScope scope;
  final ExprType? expected;

  /// Column name → label, shown next to the name where they differ.
  final Map<String, String> columnLabels;
  final ValueChanged<ExpressionSnippet>? onPick;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final strings = TesseraLocalizations.of(context);
    final help = strings.expressionHelp;
    final theme = Theme.of(context);
    final use = ExpressionHelpUse.of(scope, expected);
    final pick = onPick;
    final examples = expressionExamples(scope, expected);
    final custom = [
      for (final f in scope.functions.functions)
        if (f.implementation != null) f,
    ]..sort((a, b) => a.name.compareTo(b.name));

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 4),
      child: Text(text, style: theme.textTheme.titleMedium),
    );
    Widget subheading(String text) => Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 2),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
    Widget paragraph(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(text, style: theme.textTheme.bodyMedium),
    );
    Widget entry(String code, String? text, {ExpressionSnippet? snippet}) =>
        _Entry(
          code: code,
          text: text,
          onTap: pick == null || snippet == null ? null : () => pick(snippet),
        );

    return ListView(
      padding: padding,
      children: [
        paragraph(help.intro(use)),
        if (pick != null)
          Text(
            help.tapToInsert,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        if (examples.isNotEmpty) ...[
          heading(help.examples),
          for (final e in examples)
            entry(e, null, snippet: ExpressionSnippet(e)),
        ],
        if (scope.isCellScope) ...[
          heading(help.aggregates),
          paragraph(help.aggregateArgument),
          for (final a in ExpressionHelpAggregate.values)
            entry(
              a.syntax,
              strings.aggregateKindLabel(a.kind),
              snippet: a.hasParameters
                  ? ExpressionSnippet.call(a.functionName)
                  : ExpressionSnippet(a.functionName),
            ),
        ],
        if (scope.columns.isNotEmpty) ...[
          heading(help.columns),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final MapEntry(key: name, value: type)
                    in scope.columns.entries)
                  _ColumnChip(
                    code: Expr.quoteName(name),
                    label: columnLabels[name] == name
                        ? null
                        : columnLabels[name],
                    type: type,
                    typeName: strings.exprTypeName(type),
                    onPressed: pick == null
                        ? null
                        : () => pick(ExpressionSnippet(Expr.quoteName(name))),
                  ),
              ],
            ),
          ),
        ],
        heading(help.operators),
        for (final o in ExpressionHelpOperator.values)
          entry(o.syntax, help.operatorText(o)),
        heading(help.values),
        for (final l in ExpressionHelpLiteral.values)
          entry(l.syntax, help.literalText(l)),
        heading(help.rules),
        for (final r in ExpressionHelpRule.values) paragraph(help.ruleText(r)),
        heading(help.functions),
        for (final group in ExpressionHelpGroup.values)
          if (group != ExpressionHelpGroup.other) ...[
            subheading(help.groupName(group)),
            for (final f in ExpressionHelpFunction.values)
              if (f.group == group)
                entry(
                  help.function(f).signature,
                  help.function(f).description,
                  snippet: ExpressionSnippet.call(
                    f.functionName,
                    hasParameters: f.hasParameters,
                  ),
                ),
          ] else if (custom.isNotEmpty) ...[
            subheading(help.groupName(group)),
            for (final f in custom)
              entry(
                _signature(f, strings),
                null,
                snippet: ExpressionSnippet.call(
                  f.name,
                  hasParameters: f.parameters.isNotEmpty,
                ),
              ),
          ],
      ],
    );
  }

  /// `vat(number) → number` in this language's type names.
  static String _signature(ExpressionFunction f, TesseraStrings strings) {
    final parameters = [
      for (var i = 0; i < f.parameters.length; i++)
        strings.exprTypeName(f.parameters[i]) +
            (i >= f.minArguments ? '?' : ''),
      if (f.variadic) '…',
    ];
    return '${f.name}(${parameters.join(', ')}) → '
        '${strings.exprTypeName(f.returns)}';
  }
}

/// Up to four examples for an expression in [scope] checked as
/// [expected], written with the scope's own columns; only those that
/// validate are kept.
@visibleForTesting
List<String> expressionExamples(ExpressionScope scope, ExprType? expected) {
  final byType = <ExprType, List<String>>{};
  for (final MapEntry(key: name, value: type) in scope.columns.entries) {
    byType.putIfAbsent(type, () => []).add(Expr.quoteName(name));
  }
  String? first(ExprType type, [int index = 0]) {
    final names = byType[type];
    return names != null && names.length > index ? names[index] : null;
  }

  final n = first(ExprType.number), n2 = first(ExprType.number, 1);
  final t = first(ExprType.text), d = first(ExprType.date);
  final b = first(ExprType.boolean);
  final year = DateTime.now().year;
  final candidates = switch (ExpressionHelpUse.of(scope, expected)) {
    ExpressionHelpUse.filter => [
      if (n != null) '$n > 100',
      if (t != null) 'startswith($t, "A")',
      if (d != null) 'year($d) = $year',
      if (n != null && t != null) '$n between 10 and 100 or $t is empty',
      if (b != null) 'not $b',
    ],
    ExpressionHelpUse.measure => [
      if (n != null && n2 != null) '$n * $n2',
      if (n != null) '$n * 1.27',
      if (n != null) 'coalesce($n, 0)',
      if (n != null && b != null) 'if($b, $n, 0)',
      if (t != null) 'len($t)',
    ],
    ExpressionHelpUse.dimension => [
      if (n != null) 'floor($n / 100) * 100',
      if (n != null) '$n >= 100',
      if (t != null) 'left($t, 1)',
      if (d != null) 'weekday($d) >= 6',
      if (t != null) 'upper(trim($t))',
    ],
    ExpressionHelpUse.formula => [
      if (n != null) 'sum($n) / count',
      if (n != null && n2 != null) 'sum($n) / sum($n2)',
      if (n != null) 'max($n) - min($n)',
      if (n != null) 'round(avg($n), 2)',
      if (t != null) 'distinct($t)',
    ],
  };
  return [
    for (final c in candidates)
      if (Expression.validate(c, scope: scope, expected: expected) == null) c,
  ].take(4).toList();
}

/// One line of code and, below it, what it does; tappable with [onTap].
class _Entry extends StatelessWidget {
  const _Entry({required this.code, this.text, this.onTap});

  final String code;
  final String? text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = this.text;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              code,
              style: TextStyle(
                fontFamily: 'monospace',
                color: onTap == null
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.primary,
              ),
            ),
            if (text != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  text,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A column as it is written in an expression, its label beside it where
/// that differs, an icon for its type.
class _ColumnChip extends StatelessWidget {
  const _ColumnChip({
    required this.code,
    required this.type,
    required this.typeName,
    this.label,
    this.onPressed,
  });

  final String code;
  final String? label;
  final ExprType type;
  final String typeName;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final label = this.label;
    final name = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: code,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
          if (label != null)
            TextSpan(
              text: ' · $label',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
    final icon = Icon(switch (type) {
      ExprType.number => Icons.numbers,
      ExprType.text => Icons.text_fields,
      ExprType.date => Icons.calendar_today,
      ExprType.boolean => Icons.check_box_outlined,
    }, size: 18);
    return Tooltip(
      message: typeName,
      child: ActionChip(
        avatar: icon,
        label: name,
        onPressed: onPressed,
        // A chip without onPressed is drawn disabled; the help shown
        // without insertion is still to be read.
        disabledColor: Theme.of(context).colorScheme.surfaceContainerLow,
      ),
    );
  }
}
