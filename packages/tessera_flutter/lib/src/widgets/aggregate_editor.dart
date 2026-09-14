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
/// * With [onSelectedChanged] set, chips toggle membership in [selected] —
///   the way to let the user choose which aggregates a [CubeView] displays
///   (in the spec's order). The last selected one cannot be deselected;
///   removing a selected aggregate reports the remaining selection.
/// * A long press or secondary click on a chip opens its menu: "Show
///   values as" wraps the aggregate in a [LayoutAggregate] of the chosen
///   [ValueDisplay] (percent of a total, difference from the previous
///   group, running total, rank) or unwraps it ("Plain value").
class AggregateEditor extends StatelessWidget {
  const AggregateEditor({
    super.key,
    required this.controller,
    this.selected,
    this.onSelectedChanged,
    this.measures,
    this.dimensions,
    this.functions,
    this.label,
    this.addTooltip,
  });

  final CubeController controller;

  /// The aggregates shown as selected.
  final Set<Aggregate>? selected;

  /// Called with the new selection when a chip is toggled (or a selected
  /// aggregate removed); the set is in the spec's order.
  final ValueChanged<List<Aggregate>>? onSelectedChanged;

  /// Measures offered by the picker; defaults to the numeric columns.
  final List<Measure>? measures;

  /// Dimensions offered by the picker for distinct counts; defaults to
  /// [standardDimensions].
  final List<Dimension>? dimensions;

  /// Functions beyond the built-in ones the picker's expressions may call.
  final FunctionRegistry? functions;

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
                    MenuAnchor(
                      menuChildren: [
                        SubmenuButton(
                          menuChildren: [
                            for (final d in ValueDisplay.values)
                              MenuItemButton(
                                leadingIcon: Icon(
                                  ValueDisplay.of(a) == d ? Icons.check : null,
                                  size: 18,
                                ),
                                onPressed: () => _replace(a, d.apply(a)),
                                child: Text(strings.valueDisplayName(d)),
                              ),
                          ],
                          child: Text(strings.showValuesAs),
                        ),
                      ],
                      builder: (context, menu, _) => GestureDetector(
                        onLongPress: () => menu.open(),
                        onSecondaryTapDown: (d) =>
                            menu.open(position: d.localPosition),
                        child: InputChip(
                          label: Text(strings.aggregateLabel(a, cube.facts)),
                          selected: selected?.contains(a) ?? false,
                          onSelected: onSelectedChanged == null
                              ? null
                              : (on) => _toggle(a, on),
                          onDeleted: aggregates.length > 1
                              ? () => _remove(a)
                              : null,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
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

  /// The current selection in the spec's order, with [a] added or removed;
  /// the last one stays.
  void _toggle(Aggregate a, bool on) {
    final current = selected ?? const <Aggregate>{};
    if (!on && current.length <= 1) return;
    final next = [
      for (final x in controller.cube.spec.aggregates)
        if (x == a ? on : current.contains(x)) x,
    ];
    onSelectedChanged?.call(next);
  }

  Future<void> _pick(BuildContext context) async {
    final cube = controller.cube;
    final picked = await showAggregatePicker(
      context,
      facts: cube.facts,
      measures: measures,
      dimensions: dimensions,
      used: cube.spec.aggregates.toSet(),
      functions: functions,
    );
    if (picked == null) return;
    final spec = controller.cube.spec;
    controller.updateSpec(
      spec.copyWith(aggregates: [...spec.aggregates, picked]),
    );
  }

  /// Puts [next] where [old] was, in the spec, in any sort that used it
  /// and in the selection.
  void _replace(Aggregate old, Aggregate next) {
    if (next == old) return;
    final spec = controller.cube.spec;
    if (spec.aggregates.contains(next)) return;
    CubeAxis fix(CubeAxis axis) => axis.copyWith(
      dimensions: [
        for (final d in axis.dimensions)
          d.sort?.aggregate == old
              ? AxisDimension(
                  d.dimension,
                  sort: AxisSort(
                    by: SortBy.aggregate,
                    aggregate: next,
                    keyPath: d.sort!.keyPath,
                    direction: d.sort!.direction,
                    nulls: d.sort!.nulls,
                  ),
                )
              : d,
      ],
    );
    final aggregates = [for (final a in spec.aggregates) a == old ? next : a];
    if (selected?.contains(old) ?? false) {
      onSelectedChanged?.call([
        for (final a in aggregates)
          if (a == next || selected!.contains(a)) a,
      ]);
    }
    controller.updateSpec(
      spec.copyWith(
        aggregates: aggregates,
        rows: fix(spec.rows),
        columns: fix(spec.columns),
      ),
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
    // Let the owner drop the removed aggregate from its selection before
    // the cube changes (falling back to the first remaining one).
    if (selected?.contains(aggregate) ?? false) {
      final next = [
        for (final x in remaining)
          if (selected!.contains(x)) x,
      ];
      onSelectedChanged?.call(next.isEmpty ? [remaining.first] : next);
    }
    controller.updateSpec(
      spec.copyWith(
        aggregates: remaining,
        rows: fix(spec.rows),
        columns: fix(spec.columns),
      ),
    );
  }
}
