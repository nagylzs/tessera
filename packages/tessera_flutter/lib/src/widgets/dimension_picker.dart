import 'package:flutter/material.dart';
import 'package:tessera/tessera.dart';

import '../l10n/tessera_localizations.dart';
import 'expression_field.dart';
import 'picker_frame.dart';

/// Shows a searchable list of [dimensions] and returns the one picked, or
/// `null` if dismissed. Dimensions in [used] are listed but disabled, with
/// [usedHint] as their subtitle. Texts default to the [TesseraStrings]
/// of [context]; [labelOf] overrides how a dimension is named (default:
/// [Dimension.label]). On a short screen (a phone in landscape) the
/// picker takes the whole screen and leaves the keyboard closed until
/// the search field is tapped.
///
/// With [facts] given, an "Expression…" entry ends the list: a computed
/// dimension ([ExpressionDimension], `floor(year / 10) * 10`) over the
/// columns of [facts], validated as the user types, with an optional
/// label; [functions] are the functions beyond the built-in ones it may
/// call.
Future<Dimension?> showDimensionPicker(
  BuildContext context, {
  required List<Dimension> dimensions,
  Set<Dimension> used = const {},
  String? title,
  String? searchHint,
  String? usedHint,
  String Function(Dimension)? labelOf,
  FactTable? facts,
  FunctionRegistry? functions,
}) => showDialog<Dimension>(
  context: context,
  builder: (context) => DimensionPickerDialog(
    dimensions: dimensions,
    used: used,
    title: title,
    searchHint: searchHint,
    usedHint: usedHint,
    labelOf: labelOf,
    facts: facts,
    functions: functions,
  ),
);

/// The dialog behind [showDimensionPicker]; pops with the chosen
/// [Dimension].
class DimensionPickerDialog extends StatefulWidget {
  const DimensionPickerDialog({
    super.key,
    required this.dimensions,
    this.used = const {},
    this.title,
    this.searchHint,
    this.usedHint,
    this.labelOf,
    this.facts,
    this.functions,
  });

  final List<Dimension> dimensions;
  final Set<Dimension> used;
  final String? title;
  final String? searchHint;
  final String? usedHint;
  final String Function(Dimension)? labelOf;

  /// Enables the "Expression…" entry; the columns its expression may use.
  final FactTable? facts;

  /// Functions beyond the built-in ones the expression may call.
  final FunctionRegistry? functions;

  @override
  State<DimensionPickerDialog> createState() => _DimensionPickerDialogState();
}

class _DimensionPickerDialogState extends State<DimensionPickerDialog> {
  var _query = '';

  /// The expression entry is open.
  var _expression = false;
  var _source = '';
  ExpressionError? _error = const ExpressionError(
    ExpressionErrorKind.unexpectedEnd,
    offset: 0,
    length: 0,
  );
  var _label = '';

  @override
  Widget build(BuildContext context) {
    final strings = TesseraLocalizations.of(context);
    final labelOf = widget.labelOf ?? (Dimension d) => d.label;
    final q = _query.trim().toLowerCase();
    final shown = [
      for (final d in widget.dimensions)
        if (q.isEmpty ||
            labelOf(d).toLowerCase().contains(q) ||
            d.id.toLowerCase().contains(q))
          d,
    ];
    final title = widget.title ?? strings.addDimension;
    final short = isShortScreen(context);
    final search = TextField(
      autofocus: !short,
      decoration: InputDecoration(
        hintText: widget.searchHint ?? strings.search,
        prefixIcon: const Icon(Icons.search),
        isDense: true,
      ),
      onChanged: (v) => setState(() => _query = v),
    );
    final facts = widget.facts;
    final open = facts != null && _expression;
    // Swaps the list for the expression form and back.
    final entry = ListTile(
      dense: true,
      leading: const Icon(Icons.functions),
      title: Text('${strings.expression}…'),
      trailing: open ? const Icon(Icons.close) : null,
      selected: open,
      onTap: () => setState(() {
        _expression = !_expression;
        _source = '';
        _label = '';
        _error = const ExpressionError(
          ExpressionErrorKind.unexpectedEnd,
          offset: 0,
          length: 0,
        );
      }),
    );
    final list = ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        // The open form scrolls with its entry above it: pinned, the entry
        // left a phone in landscape too little room above the keyboard.
        if (open) ...[
          entry,
          _expressionForm(context, facts),
        ] else
          for (final d in shown)
            ListTile(
              dense: true,
              enabled: !widget.used.contains(d),
              title: Text(labelOf(d)),
              subtitle: Text(
                widget.used.contains(d)
                    ? widget.usedHint ?? strings.alreadyInUse
                    : d.id,
              ),
              onTap: widget.used.contains(d)
                  ? null
                  : () => Navigator.pop(context, d),
            ),
      ],
    );
    // Pinned under the list, where a long list cannot hide it.
    final body = facts == null || open
        ? list
        : Column(
            children: [
              Expanded(child: list),
              const Divider(height: 1),
              entry,
            ],
          );
    if (short) {
      return FullScreenPicker(
        title: title,
        control: open ? null : search,
        body: body,
      );
    }
    return AlertDialog(
      title: Text(title),
      contentPadding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
      content: SizedBox(
        width: 360,
        height: 420,
        child: Column(
          children: [
            if (!open) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: search,
              ),
              const SizedBox(height: 8),
            ],
            Expanded(child: body),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
      ],
    );
  }

  /// An expression field, a label field and an add button, like the
  /// aggregate picker's calculated measure. The expression may have any
  /// type: numbers, texts, dates and booleans all group.
  Widget _expressionForm(BuildContext context, FactTable facts) {
    final strings = TesseraLocalizations.of(context);
    final valid = _error == null && _source.trim().isNotEmpty;
    Dimension build() => ExpressionDimension(
      _source,
      label: _label.trim().isEmpty ? null : _label.trim(),
      functions: widget.functions,
    );
    final used = valid && widget.used.contains(build());
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExpressionField(
            scope: ExpressionScope.ofFacts(facts, functions: widget.functions),
            initialValue: _source,
            hintText: 'floor(year / 10) * 10',
            columnLabels: {for (final c in facts.columns) c.name: c.label},
            autofocus: true,
            onChanged: (v) => setState(() {
              _source = v.source;
              _error = v.error;
            }),
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: InputDecoration(
              isDense: true,
              labelText: strings.labelField,
            ),
            onChanged: (v) => setState(() => _label = v),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton(
              onPressed: valid && !used
                  ? () => Navigator.pop(context, build())
                  : null,
              child: Text(strings.addDimension),
            ),
          ),
          if (used)
            Text(
              widget.usedHint ?? strings.alreadyInUse,
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}
