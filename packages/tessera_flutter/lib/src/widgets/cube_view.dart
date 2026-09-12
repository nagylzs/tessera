import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';
import 'package:tessera/tessera.dart';

import '../l10n/tessera_localizations.dart';
import 'cube_controller.dart';
import 'cube_theme.dart';

/// Formats a cell's aggregate value for display. Called only for non-empty
/// cells; empty cells are rendered blank.
typedef CellFormatter = String Function(CubeCell cell, Object? value);

/// Text style for a cell's value, e.g. to colour zeros and negatives.
/// Return `null` to keep the theme's style.
typedef CellStyler = TextStyle? Function(CubeCell cell, Object? value);

/// Asked before expanding [entry] when doing so would add more than
/// [CubeView.expansionLimit] rows or columns. Return `false` to cancel.
typedef ExpansionConfirmation = Future<bool> Function(
  BuildContext context,
  HeaderEntry entry, {
  required bool isRow,
});

/// Displays a [Cube] as a pivot grid: a hierarchical column header band, a
/// hierarchical row header, and one aggregate value per cell.
///
/// Layout, following the outline model of the cube:
///
/// * one header row per column dimension, plus a row with the aggregate's
///   name; one header column per row dimension;
/// * an expanded group's label spans its children ("rotated L"); the group's
///   own row/column carries its subtotal;
/// * the top-left corner names the column dimensions (right-aligned, one
///   per header row) and the row dimensions (one per header column).
///
/// Interaction: `+`/`−` on a group toggles it via the [controller]; tapping
/// a dimension name sorts that level by value (tap again to flip); tapping
/// the aggregate name under a column sorts every row level by that column's
/// values (tap again to flip). Cells are built lazily, so large cubes stay
/// cheap to scroll.
///
/// v1 shows a single [aggregate] per cell. Needs a [Material] ancestor.
class CubeView extends StatelessWidget {
  const CubeView({
    super.key,
    required this.controller,
    required this.aggregate,
    this.theme = const CubeTheme(),
    this.formatCell,
    this.styleCell,
    this.emptyGroupLabel,
    this.rowSummaryLabel,
    this.columnSummaryLabel,
    this.sortable = true,
    this.expansionLimit = 200,
    this.confirmExpansion,
    this.onCellTap,
  });

  final CubeController controller;

  /// Which of the spec's aggregates to show in the cells. If it is not
  /// among them (e.g. it was just removed), the spec's first aggregate is
  /// shown instead; with no aggregates at all, cells stay blank.
  final Aggregate aggregate;

  final CubeTheme theme;

  /// Defaults to [TesseraStrings.formatNumber].
  final CellFormatter? formatCell;

  /// Defaults to a muted colour for zero and the error colour for negative
  /// numbers.
  final CellStyler? styleCell;

  /// Header text for the group of facts lacking a value. Defaults to the
  /// localized text (see [TesseraStrings]).
  final String? emptyGroupLabel;

  /// Header text of the summary row. Defaults to the localized text.
  final String? rowSummaryLabel;

  /// Header text of the summary column. Defaults to the localized text.
  final String? columnSummaryLabel;

  /// Whether tapping headers changes the sort order.
  final bool sortable;

  /// Expansions adding more than this many rows/columns go through
  /// [confirmExpansion] (or a default dialog).
  final int expansionLimit;

  final ExpansionConfirmation? confirmExpansion;

  final void Function(CubeCell cell)? onCellTap;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => _CubeGrid(
      view: this,
      theme: theme.resolve(context),
      strings: TesseraLocalizations.of(context),
    ),
  );
}

class _CubeGrid extends StatelessWidget {
  _CubeGrid({required this.view, required this.theme, required this.strings})
    : layout = view.controller.cube.layout,
      rowGeometry = AxisGeometry(view.controller.cube.layout.rows),
      columnGeometry = AxisGeometry(view.controller.cube.layout.columns);

  final CubeView view;
  final ResolvedCubeTheme theme;
  final TesseraStrings strings;
  final CubeLayout layout;
  final AxisGeometry rowGeometry;
  final AxisGeometry columnGeometry;

  CubeSpec get spec => layout.spec;

  /// The aggregate actually displayed (see [CubeView.aggregate]).
  Aggregate? get shown => spec.aggregates.contains(view.aggregate)
      ? view.aggregate
      : spec.aggregates.firstOrNull;
  int get rowDepth => spec.rows.depth;
  int get columnDepth => spec.columns.depth;

  /// Header columns on the left: one per row dimension, at least one.
  int get headerColumns => math.max(rowDepth, 1);

  /// Header rows carrying column-group labels: one per column dimension,
  /// at least one.
  int get levelRows => math.max(columnDepth, 1);

  /// Header rows on top: [levelRows] plus the aggregate row.
  int get headerRows => levelRows + 1;

  @override
  Widget build(BuildContext context) => TableView.builder(
    rowCount: headerRows + layout.rows.length,
    columnCount: headerColumns + layout.columns.length,
    pinnedRowCount: headerRows,
    pinnedColumnCount: headerColumns,
    columnBuilder: (index) => TableSpan(
      extent: FixedTableSpanExtent(
        index < headerColumns ? theme.rowHeaderWidth : theme.columnWidth,
      ),
    ),
    rowBuilder: (index) => TableSpan(
      extent: FixedTableSpanExtent(
        index < headerRows ? theme.headerRowHeight : theme.rowHeight,
      ),
    ),
    cellBuilder: (context, vicinity) {
      final r = vicinity.row, c = vicinity.column;
      if (r < headerRows && c < headerColumns) return _corner(context, r, c);
      if (r < headerRows) return _columnHeader(context, r, c - headerColumns);
      if (c < headerColumns) return _rowHeader(context, r - headerRows, c);
      return _dataCell(context, r - headerRows, c - headerColumns);
    },
  );

  // ---------------------------------------------------------------- corner

  TableViewCell _corner(BuildContext context, int r, int c) {
    if (r < levelRows) {
      if (columnDepth == 0) {
        return TableViewCell(
          child: _box(color: theme.headerColor, child: const SizedBox()),
        );
      }
      final level = spec.columns.dimensions[r];
      return TableViewCell(
        columnMergeStart: headerColumns > 1 ? 0 : null,
        columnMergeSpan: headerColumns > 1 ? headerColumns : null,
        child: _box(
          color: theme.headerColor,
          alignment: Alignment.centerRight,
          onTap: view.sortable
              ? () => _sortByValue(isRow: false, level: r)
              : null,
          child: _titleText(
            strings.dimensionLabel(level.dimension, layout.facts),
            level.sort,
            trailingIcon: true,
          ),
        ),
      );
    }
    if (rowDepth == 0) {
      return TableViewCell(
        child: _box(color: theme.headerColor, child: const SizedBox()),
      );
    }
    final level = spec.rows.dimensions[c];
    return TableViewCell(
      child: _box(
        color: theme.headerColor,
        alignment: Alignment.centerLeft,
        onTap: view.sortable ? () => _sortByValue(isRow: true, level: c) : null,
        child: _titleText(
          strings.dimensionLabel(level.dimension, layout.facts),
          level.sort,
          trailingIcon: true,
        ),
      ),
    );
  }

  Widget _titleText(String text, AxisSort sort, {required bool trailingIcon}) {
    final icon = sort.by == SortBy.value ? _sortIcon(sort.direction) : null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            text,
            style: theme.headerTextStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ?icon,
      ],
    );
  }

  Widget _sortIcon(SortDirection direction) => Icon(
    direction == SortDirection.ascending
        ? Icons.arrow_upward
        : Icons.arrow_downward,
    size: 12,
  );

  // --------------------------------------------------------- column header

  TableViewCell _columnHeader(BuildContext context, int r, int j) {
    final entry = layout.columns.entries[j];
    if (r == levelRows) {
      final isKey = _isSortKeyColumn(entry);
      return TableViewCell(
        child: _box(
          color: entry.isSummary ? theme.summaryColor : theme.headerColor,
          alignment: Alignment.centerRight,
          onTap: view.sortable ? () => _sortRowsByColumn(entry) : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  shown == null
                      ? ''
                      : strings.aggregateLabel(shown!, layout.facts),
                  style: theme.headerTextStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isKey) _sortIcon(_rowSortDirection()),
            ],
          ),
        ),
      );
    }
    if (columnDepth == 0) {
      return TableViewCell(
        child: _box(
          color: theme.summaryColor,
          alignment: Alignment.topLeft,
          child: _entryLabel(
            context,
            entry,
            isRow: false,
            summaryLabel: view.columnSummaryLabel ?? strings.total,
          ),
        ),
      );
    }
    final area = columnGeometry.areaAt(r, j);
    final owner = layout.columns.entries[area.entryIndex];
    return TableViewCell(
      rowMergeStart: area.levelSpan > 1 ? area.levelStart : null,
      rowMergeSpan: area.levelSpan > 1 ? area.levelSpan : null,
      columnMergeStart: area.entrySpan > 1
          ? headerColumns + area.entryStart
          : null,
      columnMergeSpan: area.entrySpan > 1 ? area.entrySpan : null,
      child: _box(
        color: owner.isSummary ? theme.summaryColor : theme.headerColor,
        alignment: Alignment.topLeft,
        child: area.isLabel
            ? _entryLabel(
                context,
                owner,
                isRow: false,
                summaryLabel: view.columnSummaryLabel ?? strings.total,
              )
            : const SizedBox(),
      ),
    );
  }

  // ------------------------------------------------------------ row header

  TableViewCell _rowHeader(BuildContext context, int i, int c) {
    final entry = layout.rows.entries[i];
    if (rowDepth == 0) {
      return TableViewCell(
        child: _box(
          color: theme.summaryColor,
          alignment: Alignment.centerLeft,
          child: _entryLabel(
            context,
            entry,
            isRow: true,
            summaryLabel: view.rowSummaryLabel ?? strings.total,
          ),
        ),
      );
    }
    final area = rowGeometry.areaAt(c, i);
    final owner = layout.rows.entries[area.entryIndex];
    return TableViewCell(
      columnMergeStart: area.levelSpan > 1 ? area.levelStart : null,
      columnMergeSpan: area.levelSpan > 1 ? area.levelSpan : null,
      rowMergeStart: area.entrySpan > 1 ? headerRows + area.entryStart : null,
      rowMergeSpan: area.entrySpan > 1 ? area.entrySpan : null,
      child: _box(
        color: owner.isSummary ? theme.summaryColor : theme.headerColor,
        alignment: Alignment.topLeft,
        child: area.isLabel
            ? _entryLabel(
                context,
                owner,
                isRow: true,
                summaryLabel: view.rowSummaryLabel ?? strings.total,
              )
            : const SizedBox(),
      ),
    );
  }

  Widget _entryLabel(
    BuildContext context,
    HeaderEntry entry, {
    required bool isRow,
    required String summaryLabel,
  }) {
    final text = entry.isSummary
        ? summaryLabel
        : entry.value == null
        ? view.emptyGroupLabel ?? strings.emptyGroup
        : strings.formatValue(entry.dimension, entry.value);
    final style = entry.isSummary
        ? theme.headerTextStyle.copyWith(fontWeight: FontWeight.bold)
        : theme.headerTextStyle;
    return SizedBox(
      height: isRow ? theme.rowHeight : theme.headerRowHeight,
      child: Row(
        children: [
          if (entry.isExpandable)
            InkWell(
              onTap: () => _toggle(context, entry, isRow: isRow),
              child: Icon(
                entry.isExpanded ? Icons.remove : Icons.add,
                size: 14,
              ),
            ),
          if (entry.isExpandable) const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ data cells

  TableViewCell _dataCell(BuildContext context, int i, int j) {
    final rowEntry = layout.rows.entries[i];
    final colEntry = layout.columns.entries[j];
    final cell = layout.cellAt(i, j);
    final summary = rowEntry.isSummary || colEntry.isSummary;
    var color = summary
        ? theme.summaryColor
        : theme.levelColor(
            math.max(rowEntry.depth, colEntry.depth) - 1,
            math.max(rowDepth, columnDepth) - 1,
          );
    if (_isSortKeyColumn(colEntry)) {
      color = Color.alphaBlend(theme.sortKeyColor, color);
    }
    Widget child = const SizedBox();
    final aggregate = shown;
    if (!cell.isEmpty && aggregate != null) {
      final value = cell.aggregate<Object?>(aggregate);
      final text = (view.formatCell ?? _defaultFormat)(cell, value);
      var style = theme.cellTextStyle;
      if (summary) style = style.copyWith(fontWeight: FontWeight.bold);
      final custom =
          view.styleCell?.call(cell, value) ?? _defaultStyle(context, value);
      if (custom != null) style = style.merge(custom);
      child = Text(
        text,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    final onTap = view.onCellTap;
    return TableViewCell(
      child: _box(
        color: color,
        alignment: Alignment.centerRight,
        onTap: onTap == null ? null : () => onTap(cell),
        child: child,
      ),
    );
  }

  String _defaultFormat(CubeCell cell, Object? value) => switch (value) {
    null => '',
    num v => strings.formatNumber(v),
    _ => value.toString(),
  };

  static TextStyle? _defaultStyle(BuildContext context, Object? value) {
    if (value is! num) return null;
    final scheme = Theme.of(context).colorScheme;
    if (value == 0) return TextStyle(color: scheme.outline);
    if (value < 0) return TextStyle(color: scheme.error);
    return null;
  }

  // ------------------------------------------------------------- behaviour

  Widget _box({
    required Color color,
    required Widget child,
    Alignment alignment = Alignment.centerLeft,
    VoidCallback? onTap,
  }) {
    final box = Container(
      decoration: BoxDecoration(
        color: color,
        border: Border(
          right: BorderSide(color: theme.borderColor),
          bottom: BorderSide(color: theme.borderColor),
        ),
      ),
      padding: theme.cellPadding,
      alignment: alignment,
      child: child,
    );
    return onTap == null ? box : InkWell(onTap: onTap, child: box);
  }

  Future<void> _toggle(
    BuildContext context,
    HeaderEntry entry, {
    required bool isRow,
  }) async {
    final controller = view.controller;
    if (!entry.isExpanded && entry.childCount > view.expansionLimit) {
      final confirm = view.confirmExpansion ?? _defaultConfirm;
      if (!await confirm(context, entry, isRow: isRow)) return;
    }
    if (isRow) {
      controller.toggleRow(entry.path);
    } else {
      controller.toggleColumn(entry.path);
    }
  }

  Future<bool> _defaultConfirm(
    BuildContext context,
    HeaderEntry entry, {
    required bool isRow,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.largeExpansionTitle),
        content: Text(
          strings.largeExpansion(
            entry.isSummary
                ? (isRow ? view.rowSummaryLabel : view.columnSummaryLabel) ??
                      strings.total
                : entry.value == null
                ? view.emptyGroupLabel ?? strings.emptyGroup
                : strings.formatValue(entry.dimension, entry.value),
            entry.childCount,
            isRow: isRow,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.expand),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  bool _isSortKeyColumn(HeaderEntry column) => spec.rows.dimensions.any((d) {
    final s = d.sort;
    if (s.by != SortBy.aggregate || s.aggregate != shown) return false;
    final key = s.keyPath;
    return key == null ? column.isSummary : key == column.path;
  });

  SortDirection _rowSortDirection() => spec.rows.dimensions
      .map((d) => d.sort)
      .firstWhere((s) => s.by == SortBy.aggregate, orElse: AxisSort.new)
      .direction;

  void _sortByValue({required bool isRow, required int level}) {
    final axis = isRow ? spec.rows : spec.columns;
    final current = axis.dimensions[level].sort;
    final direction =
        current.by == SortBy.value &&
            current.direction == SortDirection.ascending
        ? SortDirection.descending
        : SortDirection.ascending;
    final dims = List.of(axis.dimensions);
    dims[level] = AxisDimension(
      dims[level].dimension,
      sort: AxisSort(direction: direction, nulls: current.nulls),
    );
    _updateAxis(
      isRow: isRow,
      axis: axis.copyWith(dimensions: dims),
    );
  }

  void _sortRowsByColumn(HeaderEntry column) {
    final aggregate = shown;
    if (aggregate == null) return;
    final keyPath = column.isSummary ? null : column.path;
    final first = spec.rows.dimensions.firstOrNull?.sort;
    final same =
        first != null &&
        first.by == SortBy.aggregate &&
        first.aggregate == aggregate &&
        first.keyPath == keyPath;
    final direction = same && first.direction == SortDirection.descending
        ? SortDirection.ascending
        : SortDirection.descending;
    final dims = [
      for (final d in spec.rows.dimensions)
        AxisDimension(
          d.dimension,
          sort: AxisSort(
            by: SortBy.aggregate,
            aggregate: aggregate,
            keyPath: keyPath,
            direction: direction,
            nulls: d.sort.nulls,
          ),
        ),
    ];
    _updateAxis(isRow: true, axis: spec.rows.copyWith(dimensions: dims));
  }

  void _updateAxis({required bool isRow, required CubeAxis axis}) {
    view.controller.updateSpec(
      isRow ? spec.copyWith(rows: axis) : spec.copyWith(columns: axis),
    );
  }
}
