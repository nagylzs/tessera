import 'package:flutter/material.dart';

import '../cube/cube_spec.dart';
import '../facts/dimension.dart';
import '../facts/standard_dimensions.dart';
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
    this.emptyHint = 'Drop dimensions here',
    this.addTooltip = 'Add dimension',
  });

  final CubeController controller;
  final AxisSide side;

  /// Dimensions offered by the picker.
  final List<Dimension>? available;

  /// Caption in front of the chips; defaults to "Rows" / "Columns".
  final String? label;

  final String emptyHint;
  final String addTooltip;

  CubeAxis _axisOf(CubeSpec spec, AxisSide s) =>
      s == AxisSide.rows ? spec.rows : spec.columns;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final spec = controller.cube.spec;
      final dims = _axisOf(spec, side).dimensions;
      final theme = Theme.of(context);
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
                child: Text(
                  label ?? (side == AxisSide.rows ? 'Rows' : 'Columns'),
                  style: theme.textTheme.labelLarge,
                ),
              ),
              Expanded(
                child: dims.isEmpty
                    ? Text(emptyHint, style: theme.textTheme.bodySmall)
                    : Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (var i = 0; i < dims.length; i++)
                            _chip(context, dims[i].dimension, i),
                        ],
                      ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: addTooltip,
                onPressed: () => _pick(context),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _chip(BuildContext context, Dimension dimension, int index) {
    final label = dimension.labelFor(controller.cube.facts);
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
    final spec = controller.cube.spec;
    final used = {
      for (final d in spec.rows.dimensions) d.dimension,
      for (final d in spec.columns.dimensions) d.dimension,
    };
    final picked = await showDimensionPicker(
      context,
      dimensions: available ?? standardDimensions(controller.cube.facts),
      used: used,
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
