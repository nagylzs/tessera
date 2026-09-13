import 'package:flutter/material.dart';
import 'package:tessera/tessera.dart';

import '../l10n/tessera_localizations.dart';
import 'cube_controller.dart';
import 'dimension_picker.dart';

/// Which axis of the cube an [AxisEditor] edits.
enum AxisSide { rows, columns }

/// Payload of a dimension being dragged between (or within) [AxisEditor]s.
/// Public so custom widgets can act as drag sources or targets.
final class DimensionDrag {
  const DimensionDrag(this.dimension, {this.from});

  final Dimension dimension;

  /// Axis the dimension is dragged from; `null` when it comes from
  /// elsewhere (a palette of unused dimensions, say).
  final AxisSide? from;
}

/// Edits the dimensions of one axis of a [CubeController]'s cube as a row
/// of chips.
///
/// * Drag a chip onto another chip to insert it before that chip; drop it
///   on empty space to append. Chips can be dragged between the rows editor
///   and the columns editor.
/// * The chip's delete icon removes the dimension from the axis.
/// * The `+` button opens [showDimensionPicker] with [available] (default:
///   [standardDimensions] of the cube's facts); dimensions already on the
///   other axis are moved over.
///
/// Sort settings travel with the dimension.
class AxisEditor extends StatelessWidget {
  const AxisEditor({
    super.key,
    required this.controller,
    required this.side,
    this.available,
    this.label,
    this.emptyHint,
    this.addTooltip,
  });

  final CubeController controller;
  final AxisSide side;

  /// Dimensions offered by the picker.
  final List<Dimension>? available;

  /// Caption in front of the chips; defaults to the localized
  /// "Rows" / "Columns".
  final String? label;

  /// Defaults to the localized texts.
  final String? emptyHint;
  final String? addTooltip;

  CubeAxis _axisOf(CubeSpec spec, AxisSide s) =>
      s == AxisSide.rows ? spec.rows : spec.columns;

  /// The caption ("Rows" / "Columns"); tapping it opens a menu with the
  /// axis's summary position ([CubeAxis.summaryPosition]).
  Widget _caption(
    BuildContext context,
    CubeSpec spec,
    TesseraStrings strings,
    ThemeData theme,
  ) {
    final current = _axisOf(spec, side).summaryPosition;
    return MenuAnchor(
      menuChildren: [
        for (final (position, text) in [
          (SummaryPosition.end, strings.totalsAtEnd),
          (SummaryPosition.start, strings.totalsAtStart),
          (SummaryPosition.hidden, strings.totalsHidden),
        ])
          MenuItemButton(
            leadingIcon: Icon(position == current ? Icons.check : null),
            onPressed: () => _setSummaryPosition(position),
            child: Text(text),
          ),
      ],
      builder: (context, menu, _) => InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () => menu.isOpen ? menu.close() : menu.open(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label ??
                    (side == AxisSide.rows ? strings.rows : strings.columns),
                style: theme.textTheme.labelLarge,
              ),
              const Icon(Icons.arrow_drop_down, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  void _setSummaryPosition(SummaryPosition position) {
    final spec = controller.cube.spec;
    final axis = _axisOf(spec, side).copyWith(summaryPosition: position);
    controller.updateSpec(
      side == AxisSide.rows
          ? spec.copyWith(rows: axis)
          : spec.copyWith(columns: axis),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final cube = controller.cube;
      final spec = cube.spec;
      final dims = _axisOf(spec, side).dimensions;
      final theme = Theme.of(context);
      final strings = TesseraLocalizations.of(context);
      return DragTarget<DimensionDrag>(
        onWillAcceptWithDetails: (d) => true,
        onAcceptWithDetails: (d) => _move(d.data),
        builder: (context, candidates, _) => Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(
              color: candidates.isNotEmpty
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              width: candidates.isNotEmpty ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _caption(context, spec, strings, theme),
              ),
              Expanded(
                child: dims.isEmpty
                    ? Text(
                        emptyHint ?? strings.dropDimensionsHere,
                        style: theme.textTheme.bodySmall,
                      )
                    : Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (var i = 0; i < dims.length; i++)
                            _chip(
                              context,
                              dims[i].dimension,
                              i,
                              strings.dimensionLabel(
                                dims[i].dimension,
                                cube.facts,
                              ),
                            ),
                        ],
                      ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: addTooltip ?? strings.addDimension,
                onPressed: () => _pick(context),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _chip(
    BuildContext context,
    Dimension dimension,
    int index,
    String label,
  ) {
    final chip = InputChip(
      label: Text(label),
      onDeleted: () => _remove(dimension),
      visualDensity: VisualDensity.compact,
    );
    return DragTarget<DimensionDrag>(
      onWillAcceptWithDetails: (d) => d.data.dimension != dimension,
      onAcceptWithDetails: (d) => _move(d.data, insertBefore: index),
      builder: (context, candidates, _) => Container(
        decoration: candidates.isEmpty
            ? null
            : BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 3,
                  ),
                ),
              ),
        child: Draggable<DimensionDrag>(
          data: DimensionDrag(dimension, from: side),
          feedback: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: Chip(
              label: Text(label),
              visualDensity: VisualDensity.compact,
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.4, child: chip),
          child: chip,
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final cube = controller.cube;
    final spec = cube.spec;
    final strings = TesseraLocalizations.of(context);
    final used = {
      for (final d in spec.rows.dimensions) d.dimension,
      for (final d in spec.columns.dimensions) d.dimension,
    };
    final picked = await showDimensionPicker(
      context,
      dimensions: available ?? standardDimensions(cube.facts),
      used: used,
      labelOf: (d) => strings.dimensionLabel(d, cube.facts),
    );
    if (picked != null) _move(DimensionDrag(picked));
  }

  void _remove(Dimension dimension) {
    final spec = controller.cube.spec;
    final axis = _axisOf(spec, side);
    final dims = [
      for (final d in axis.dimensions)
        if (d.dimension != dimension) d,
    ];
    _update(spec, side, axis.copyWith(dimensions: dims));
  }

  /// Inserts the dragged dimension into this axis before [insertBefore]
  /// (indices as currently displayed), or at the end, removing it from
  /// wherever it currently is.
  void _move(DimensionDrag drag, {int? insertBefore}) {
    final spec = controller.cube.spec;
    final rows = List.of(spec.rows.dimensions);
    final columns = List.of(spec.columns.dimensions);
    final target = side == AxisSide.rows ? rows : columns;

    AxisDimension item = AxisDimension(drag.dimension);
    var index = insertBefore ?? target.length;
    for (final list in [rows, columns]) {
      final i = list.indexWhere((d) => d.dimension == drag.dimension);
      if (i < 0) continue;
      item = list.removeAt(i);
      if (identical(list, target) && i < index) index--;
    }
    target.insert(index.clamp(0, target.length), item);

    controller.updateSpec(
      spec.copyWith(
        rows: spec.rows.copyWith(dimensions: rows),
        columns: spec.columns.copyWith(dimensions: columns),
      ),
    );
  }

  void _update(CubeSpec spec, AxisSide s, CubeAxis axis) =>
      controller.updateSpec(
        s == AxisSide.rows
            ? spec.copyWith(rows: axis)
            : spec.copyWith(columns: axis),
      );
}
