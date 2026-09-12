import 'package:flutter/material.dart';

import '../cube/aggregate.dart';
import '../facts/dimension.dart';
import '../facts/fact_table.dart';
import '../facts/measure.dart';
import '../facts/standard_dimensions.dart';
import '../l10n/tessera_localizations.dart';
import 'aggregate_kind.dart';

/// The numeric columns of [facts] as measures.
List<Measure> standardMeasures(FactTable facts) => [
  for (final c in facts.columns)
    if (c.type.isNumeric) Measure(c.name, label: c.label),
];

/// Lets the user pick a function and, where needed, a measure or dimension;
/// returns the resulting [Aggregate] or `null` if dismissed. Combinations
/// already in [used] are disabled. Texts default to the
/// [TesseraLocalizations] of [context].
Future<Aggregate?> showAggregatePicker(
  BuildContext context, {
  required FactTable facts,
  List<Measure>? measures,
  List<Dimension>? dimensions,
  Set<Aggregate> used = const {},
  String? title,
}) {
  final strings = TesseraLocalizations.of(context);
  return showDialog<Aggregate>(
    context: context,
    builder: (context) => AggregatePickerDialog(
      measures: measures ?? standardMeasures(facts),
      dimensions: dimensions ?? standardDimensions(facts),
      used: used,
      title: title,
      measureLabel: (m) => m.labelFor(facts),
      dimensionLabel: (d) => strings.dimensionLabel(d, facts),
    ),
  );
}

/// The dialog behind [showAggregatePicker]; pops with the chosen
/// [Aggregate].
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
  });

  final List<Measure> measures;
  final List<Dimension> dimensions;
  final Set<Aggregate> used;
  final String? title;
  final String? usedHint;

  /// How measures and dimensions are named; default: their [Measure.label]
  /// / [Dimension.label].
  final String Function(Measure)? measureLabel;
  final String Function(Dimension)? dimensionLabel;

  @override
  State<AggregatePickerDialog> createState() => _AggregatePickerDialogState();
}

class _AggregatePickerDialogState extends State<AggregatePickerDialog> {
  var _kind = AggregateKind.sum;

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
              child: DropdownButtonFormField<AggregateKind>(
                initialValue: _kind,
                decoration: InputDecoration(
                  isDense: true,
                  labelText: strings.function,
                ),
                items: [
                  for (final k in AggregateKind.values)
                    DropdownMenuItem(
                      value: k,
                      child: Text(strings.aggregateKindLabel(k)),
                    ),
                ],
                onChanged: (k) => setState(() => _kind = k!),
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

  Widget _targets(BuildContext context, TesseraLocalizations strings) {
    final measureLabel = widget.measureLabel ?? (Measure m) => m.label;
    final dimensionLabel = widget.dimensionLabel ?? (Dimension d) => d.label;
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

  Widget _tile(
    BuildContext context,
    TesseraLocalizations strings,
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
