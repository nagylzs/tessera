import 'package:flutter/material.dart';
import 'package:tessera/tessera.dart';

import '../l10n/tessera_localizations.dart';
import 'expression_field.dart';

/// The numeric columns of [facts] as measures.
List<Measure> standardMeasures(FactTable facts) => [
  for (final c in facts.columns)
    if (c.type.isNumeric) Measure(c.name, label: c.label),
];

/// Lets the user pick a function and, where needed, a measure or dimension;
/// returns the resulting [Aggregate] or `null` if dismissed. Combinations
/// already in [used] are disabled. Texts default to the
/// [TesseraStrings] of [context].
Future<Aggregate?> showAggregatePicker(
  BuildContext context, {
  required FactTable facts,
  List<Measure>? measures,
  List<Dimension>? dimensions,
  Set<Aggregate> used = const {},
  String? title,
  FunctionRegistry? functions,
}) {
  final strings = TesseraLocalizations.of(context);
  return showDialog<Aggregate>(
    context: context,
    builder: (context) => AggregatePickerDialog(
      measures: measures ?? standardMeasures(facts),
      dimensions: dimensions ?? standardDimensions(facts),
      used: used,
      title: title,
      facts: facts,
      functions: functions,
      measureLabel: (m) => m.labelFor(facts),
      dimensionLabel: (d) => strings.dimensionLabel(d, facts),
    ),
  );
}

/// The dialog behind [showAggregatePicker]; pops with the chosen
/// [Aggregate].
///
/// With [facts] given, two expression paths appear: a "Formula" function
/// (a cell formula such as `sum(total) / count`, an
/// [ExpressionAggregate]) and, under every measure function, an
/// "Expression" entry for a calculated measure (`quantity * unit_price`,
/// a [Measure.expression]); both validated as the user types.
class AggregatePickerDialog extends StatefulWidget {
  const AggregatePickerDialog({
    super.key,
    required this.measures,
    required this.dimensions,
    this.used = const {},
    this.title,
    this.usedHint,
    this.measureLabel,
    this.dimensionLabel,
    this.facts,
    this.functions,
  });

  final List<Measure> measures;
  final List<Dimension> dimensions;
  final Set<Aggregate> used;
  final String? title;
  final String? usedHint;

  /// Enables the expression paths; the columns expressions may use.
  final FactTable? facts;

  /// Functions beyond the built-in ones expressions may call.
  final FunctionRegistry? functions;

  /// How measures and dimensions are named; default: their [Measure.label]
  /// / [Dimension.label].
  final String Function(Measure)? measureLabel;
  final String Function(Dimension)? dimensionLabel;

  @override
  State<AggregatePickerDialog> createState() => _AggregatePickerDialogState();
}

/// A choice of the function dropdown: a built-in kind or the cell formula.
final class _Function {
  const _Function(this.kind);

  /// `null` = formula.
  final AggregateKind? kind;

  static const formula = _Function(null);

  @override
  bool operator ==(Object other) => other is _Function && other.kind == kind;

  @override
  int get hashCode => kind.hashCode;
}

class _AggregatePickerDialogState extends State<AggregatePickerDialog> {
  var _function = const _Function(AggregateKind.sum);

  /// The expression entry of the measure list is open.
  var _measureExpression = false;
  var _source = '';
  ExpressionError? _error = const ExpressionError(
    ExpressionErrorKind.unexpectedEnd,
    offset: 0,
    length: 0,
  );
  var _label = '';

  AggregateKind get _kind => _function.kind ?? AggregateKind.sum;

  @override
  Widget build(BuildContext context) {
    final strings = TesseraLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title ?? strings.addAggregate),
      contentPadding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
      content: SizedBox(
        width: 360,
        height: 420,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: DropdownButtonFormField<_Function>(
                initialValue: _function,
                isExpanded: true,
                decoration: InputDecoration(
                  isDense: true,
                  labelText: strings.function,
                ),
                items: [
                  for (final k in AggregateKind.values)
                    DropdownMenuItem(
                      value: _Function(k),
                      child: Text(
                        strings.aggregateKindLabel(k),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (widget.facts != null)
                    DropdownMenuItem(
                      value: _Function.formula,
                      child: Text(
                        strings.formula,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (f) => setState(() {
                  _function = f!;
                  _measureExpression = false;
                  _resetExpression();
                }),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _targets(context, strings)),
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

  void _resetExpression() {
    _source = '';
    _label = '';
    _error = const ExpressionError(
      ExpressionErrorKind.unexpectedEnd,
      offset: 0,
      length: 0,
    );
  }

  Widget _targets(BuildContext context, TesseraStrings strings) {
    final measureLabel = widget.measureLabel ?? (Measure m) => m.label;
    final dimensionLabel = widget.dimensionLabel ?? (Dimension d) => d.label;
    final facts = widget.facts;
    if (_function == _Function.formula && facts != null) {
      return _expressionForm(
        context,
        strings,
        scope: ExpressionScope.cellsOf(facts, functions: widget.functions),
        hint: 'sum(x) / count',
        build: () => Aggregate.expression(
          _source,
          label: _label.trim().isEmpty ? null : _label.trim(),
          functions: widget.functions,
        ),
      );
    }
    if (_kind.needsMeasure) {
      return ListView(
        children: [
          for (final m in widget.measures)
            _tile(
              context,
              strings,
              measureLabel(m),
              m.id,
              _kind.build(measure: m),
            ),
          if (facts != null)
            ListTile(
              dense: true,
              leading: const Icon(Icons.functions),
              title: Text('${strings.expression}…'),
              selected: _measureExpression,
              onTap: () => setState(() {
                _measureExpression = !_measureExpression;
                _resetExpression();
              }),
            ),
          if (facts != null && _measureExpression)
            _expressionForm(
              context,
              strings,
              scope: ExpressionScope.ofFacts(
                facts,
                functions: widget.functions,
              ),
              hint: 'quantity * unit_price',
              build: () => _kind.build(
                measure: Measure.expression(
                  _source,
                  label: _label.trim().isEmpty ? null : _label.trim(),
                  functions: widget.functions,
                ),
              ),
              shrink: true,
            ),
        ],
      );
    }
    if (_kind.needsDimension) {
      return ListView(
        children: [
          for (final d in widget.dimensions)
            _tile(
              context,
              strings,
              dimensionLabel(d),
              d.id,
              _kind.build(dimension: d),
            ),
        ],
      );
    }
    final a = _kind.build();
    return ListView(
      children: [_tile(context, strings, strings.countOfFacts, a.id, a)],
    );
  }

  /// An expression field, a label field and an add button; [build] makes
  /// the aggregate from the current text. Validated as an expression of
  /// type number in [scope].
  Widget _expressionForm(
    BuildContext context,
    TesseraStrings strings, {
    required ExpressionScope scope,
    required String hint,
    required Aggregate Function() build,
    bool shrink = false,
  }) {
    final valid = _error == null && _source.trim().isNotEmpty;
    final used = valid && widget.used.contains(build());
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Column(
        mainAxisSize: shrink ? MainAxisSize.min : MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExpressionField(
            scope: scope,
            expected: ExprType.number,
            initialValue: _source,
            hintText: hint,
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
              child: Text(strings.addAggregate),
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

  Widget _tile(
    BuildContext context,
    TesseraStrings strings,
    String title,
    String subtitle,
    Aggregate aggregate,
  ) {
    final used = widget.used.contains(aggregate);
    return ListTile(
      dense: true,
      enabled: !used,
      title: Text(title),
      subtitle: Text(used ? widget.usedHint ?? strings.alreadyInUse : subtitle),
      onTap: used ? null : () => Navigator.pop(context, aggregate),
    );
  }
}
