import 'package:flutter/material.dart';
import 'package:tessera/tessera.dart';

import '../l10n/tessera_localizations.dart';
import 'aggregate_picker.dart';
import 'cube_controller.dart';

/// Edits the aggregates of a [CubeController]'s cube as a row of chips.
///
/// * The chip's delete icon removes the aggregate. The last aggregate cannot
///   be removed. Any [AxisSort] that used the removed aggregate falls back
///   to sorting by value.
/// * The `+` button opens [showAggregatePicker].
/// * With [onSelected] set, chips are selectable and [selected] is shown as
///   selected — the way to let the user choose which aggregate a
///   [CubeView] displays. When the selected aggregate is removed,
///   [onSelected] is called with the first remaining one.
class AggregateEditor extends StatelessWidget {
  const AggregateEditor({
    super.key,
    required this.controller,
    this.selected,
    this.onSelected,
    this.measures,
    this.dimensions,
    this.label,
    this.addTooltip,
  });

  final CubeController controller;

  /// The aggregate to show as selected.
  final Aggregate? selected;

  final ValueChanged<Aggregate>? onSelected;

  /// Measures offered by the picker; defaults to the numeric columns.
  final List<Measure>? measures;

  /// Dimensions offered by the picker for distinct counts; defaults to
  /// [standardDimensions].
  final List<Dimension>? dimensions;

  /// Defaults to the localized "Values".
  final String? label;

  /// Defaults to the localized text.
  final String? addTooltip;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final cube = controller.cube;
      final aggregates = cube.spec.aggregates;
      final theme = Theme.of(context);
      final strings = TesseraLocalizations.of(context);
      return Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                label ?? strings.values,
                style: theme.textTheme.labelLarge,
              ),
            ),
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final a in aggregates)
                    InputChip(
                      label: Text(strings.aggregateLabel(a, cube.facts)),
                      selected: a == selected,
                      onSelected: onSelected == null
                          ? null
                          : (_) => onSelected!(a),
                      onDeleted: aggregates.length > 1
                          ? () => _remove(a)
                          : null,
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: addTooltip ?? strings.addAggregate,
              onPressed: () => _pick(context),
            ),
          ],
        ),
      );
    },
  );

  Future<void> _pick(BuildContext context) async {
    final cube = controller.cube;
    final picked = await showAggregatePicker(
      context,
      facts: cube.facts,
      measures: measures,
      dimensions: dimensions,
      used: cube.spec.aggregates.toSet(),
    );
    if (picked == null) return;
    final spec = controller.cube.spec;
    controller.updateSpec(
      spec.copyWith(aggregates: [...spec.aggregates, picked]),
    );
  }

  void _remove(Aggregate aggregate) {
    final spec = controller.cube.spec;
    final remaining = [
      for (final a in spec.aggregates)
        if (a != aggregate) a,
    ];
    if (remaining.isEmpty) return;
    CubeAxis fix(CubeAxis axis) => axis.copyWith(
      dimensions: [
        for (final d in axis.dimensions)
          d.sort?.aggregate == aggregate
              ? AxisDimension(
                  d.dimension,
                  sort: AxisSort(
                    direction: d.sort!.direction,
                    nulls: d.sort!.nulls,
                  ),
                )
              : d,
      ],
    );
    // Let the owner switch the displayed aggregate before the cube changes.
    if (aggregate == selected) onSelected?.call(remaining.first);
    controller.updateSpec(
      spec.copyWith(
        aggregates: remaining,
        rows: fix(spec.rows),
        columns: fix(spec.columns),
      ),
    );
  }
}
