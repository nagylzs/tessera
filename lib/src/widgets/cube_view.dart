import 'package:flutter/widgets.dart';

import '../cube/aggregate.dart';
import '../cube/cube_layout.dart';
import 'cube_controller.dart';

/// Formats a cell's aggregate value for display. Called only for non-empty
/// cells; empty cells are rendered blank.
typedef CellFormatter = String Function(CubeCell cell, Object? value);

/// Displays a [Cube] as a pivot grid: a hierarchical column header band, a
/// hierarchical row header column, and one aggregate value per cell.
///
/// Expand/collapse icons on the headers drive [CubeController.toggleRow] /
/// [CubeController.toggleColumn]; the widget rebuilds from the controller.
///
/// v1 shows a single [aggregate] per cell. The cube API already supports
/// several; showing more is a widget concern for later.
class CubeView extends StatelessWidget {
  const CubeView({
    super.key,
    required this.controller,
    required this.aggregate,
    this.formatCell,
    this.emptyGroupLabel = '(empty)',
    this.summaryLabel = 'Total',
  });

  final CubeController controller;

  /// Which of the spec's aggregates to show in the cells.
  final Aggregate aggregate;

  final CellFormatter? formatCell;

  /// Header text for the group of facts lacking a value.
  final String emptyGroupLabel;

  /// Header text for the summary row/column.
  final String summaryLabel;

  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}
