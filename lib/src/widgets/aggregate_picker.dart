import 'package:flutter/material.dart';

import '../cube/aggregate.dart';
import '../facts/dimension.dart';
import '../facts/fact_table.dart';
import '../facts/measure.dart';
import '../facts/standard_dimensions.dart';

/// The built-in aggregate functions, as offered by [showAggregatePicker].
enum AggregateKind {
  sum('Sum'),
  average('Average'),
  min('Minimum'),
  max('Maximum'),
  countNonNull('Count of values'),
  distinctCount('Distinct count'),
  count('Count of facts');

  const AggregateKind(this.label);

  final String label;

  /// Whether [build] needs a [Measure].
  bool get needsMeasure => switch (this) {
    sum || average || min || max || countNonNull => true,
    distinctCount || count => false,
  };

  /// Whether [build] needs a [Dimension].
  bool get needsDimension => this == distinctCount;

  Aggregate build({Measure? measure, Dimension? dimension}) => switch (this) {
    sum => Aggregate.sum(measure!),
    average => Aggregate.average(measure!),
    min => Aggregate.min(measure!),
    max => Aggregate.max(measure!),
    countNonNull => Aggregate.countNonNull(measure!),
    distinctCount => Aggregate.distinctCount(dimension!),
    count => Aggregate.count,
  };
}

/// The numeric columns of [facts] as measures.
List<Measure> standardMeasures(FactTable facts) => [
  for (final c in facts.columns)
    if (c.type.isNumeric) Measure(c.name, label: c.label),
];

/// Lets the user pick a function and, where needed, a measure or dimension;
/// returns the resulting [Aggregate] or `null` if dismissed. Combinations
/// already in [used] are disabled.
Future<Aggregate?> showAggregatePicker(
  BuildContext context, {
  required FactTable facts,
  List<Measure>? measures,
  List<Dimension>? dimensions,
  Set<Aggregate> used = const {},
  String title = 'Add aggregate',
}) => showDialog<Aggregate>(
  context: context,
  builder: (context) => AggregatePickerDialog(
    measures: measures ?? standardMeasures(facts),
    dimensions: dimensions ?? standardDimensions(facts),
    used: used,
    title: title,
  ),
);

/// The dialog behind [showAggregatePicker]; pops with the chosen
/// [Aggregate].
class AggregatePickerDialog extends StatefulWidget {
  const AggregatePickerDialog({
    super.key,
    required this.measures,
    required this.dimensions,
    this.used = const {},
    this.title = 'Add aggregate',
    this.usedHint = 'already in use',
  });

  final List<Measure> measures;
  final List<Dimension> dimensions;
  final Set<Aggregate> used;
  final String title;
  final String usedHint;

  @override
  State<AggregatePickerDialog> createState() => _AggregatePickerDialogState();
}

class _AggregatePickerDialogState extends State<AggregatePickerDialog> {
  var _kind = AggregateKind.sum;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
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
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Function',
              ),
              items: [
                for (final k in AggregateKind.values)
                  DropdownMenuItem(value: k, child: Text(k.label)),
              ],
              onChanged: (k) => setState(() => _kind = k!),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _targets(context)),
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

  Widget _targets(BuildContext context) {
    if (_kind.needsMeasure) {
      return ListView(
        children: [
          for (final m in widget.measures)
            _tile(context, m.label, m.id, _kind.build(measure: m)),
        ],
      );
    }
    if (_kind.needsDimension) {
      return ListView(
        children: [
          for (final d in widget.dimensions)
            _tile(context, d.label, d.id, _kind.build(dimension: d)),
        ],
      );
    }
    final a = _kind.build();
    return ListView(children: [_tile(context, _kind.label, a.id, a)]);
  }

  Widget _tile(
    BuildContext context,
    String title,
    String subtitle,
    Aggregate aggregate,
  ) {
    final used = widget.used.contains(aggregate);
    return ListTile(
      dense: true,
      enabled: !used,
      title: Text(title),
      subtitle: Text(used ? widget.usedHint : subtitle),
      onTap: used ? null : () => Navigator.pop(context, aggregate),
    );
  }
}
