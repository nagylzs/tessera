import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';
import 'package:tessera/tessera.dart';

import '../l10n/tessera_localizations.dart';
import 'column_widths.dart';
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

/// Asked before "expand all" on [dimension] (a menu item of its title) when
/// it would add more than [CubeView.expansionLimit] rows or columns.
/// Return `false` to cancel.
typedef LevelExpansionConfirmation = Future<bool> Function(
  BuildContext context,
  Dimension dimension,
  int added, {
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
/// values (tap again to flip). Each dimension name also has a menu — the
/// `▾` button, a long press or a secondary click — with the sort direction
/// and "expand all" / "collapse all" for that level. Cells are built lazily,
/// so large cubes stay cheap to scroll.
///
/// Column widths follow the content: the widest text of each column (its
/// values, labels and titles) is measured up front and the width clamped to
/// the [CubeTheme]'s bounds. Once widened, a column keeps its width for the
/// life of the view (see [keepColumnWidths]). Rows have a fixed height.
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
    this.confirmLevelExpansion,
    this.onCellTap,
    this.measuredRows = 1000,
    this.keepColumnWidths = true,
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

  /// Same for "expand all" from a dimension's menu (default: a dialog).
  final LevelExpansionConfirmation? confirmLevelExpansion;

  final void Function(CubeCell cell)? onCellTap;

  /// How many rows (from the top) contribute their values when the column
  /// widths are measured; summary rows always do. Bounds the cost of
  /// formatting every cell of a huge cube on each rebuild — a longer value
  /// further down is shown with an ellipsis.
  final int measuredRows;

  /// Whether a column keeps the widest width it has had while this view is
  /// alive, so collapsing the group that held its widest value does not
  /// make it (and everything right of it) jump. Columns are remembered by
  /// their [HeaderEntry.path] (row-header columns by dimension); the memory
  /// is dropped when the aggregate, the formatting or the theme changes.
  /// `false` resizes both ways on every change.
  final bool keepColumnWidths;

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

class _CubeGrid extends StatefulWidget {
  const _CubeGrid({
    required this.view,
    required this.theme,
    required this.strings,
  });

  final CubeView view;
  final ResolvedCubeTheme theme;
  final TesseraStrings strings;

  @override
  State<_CubeGrid> createState() => _CubeGridState();
}

/// Everything derived from the layout is recomputed on demand; the column
/// widths are cached across rebuilds of the same layout (see [_widths]).
class _CubeGridState extends State<_CubeGrid> {
  CubeView get view => widget.view;
  ResolvedCubeTheme get theme => widget.theme;
  TesseraStrings get strings => widget.strings;
  CubeLayout get layout => view.controller.cube.layout;

  AxisGeometry? _rowGeometry;
  AxisGeometry? _columnGeometry;
  AxisGeometry get rowGeometry => _rowGeometry?.layout == layout.rows
      ? _rowGeometry!
      : _rowGeometry = AxisGeometry(layout.rows);
  AxisGeometry get columnGeometry => _columnGeometry?.layout == layout.columns
      ? _columnGeometry!
      : _columnGeometry = AxisGeometry(layout.columns);

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

  // --------------------------------------------------------- column widths

  /// Room for an expand icon (14) and its gap, or a sort icon (12).
  static const _iconWidth = 18.0;

  /// Rounding slack on top of padding and border.
  static const _slack = 2.0;

  List<double>? _widths;
  Object? _widthsKey;

  /// Widest width seen per row-header column (by dimension id) and per data
  /// column (by path) under [_memoryKey]; see [CubeView.keepColumnWidths].
  final _rememberedHeader = <String, double>{};
  final _rememberedData = <DimensionPath, double>{};
  Object? _memoryKey;

  /// One width per grid column, measured from the content of [layout] and
  /// recomputed only when something that affects it changes.
  List<double> _columnWidths(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    final memoryKey = (
      shown,
      strings,
      view.formatCell,
      view.measuredRows,
      view.emptyGroupLabel,
      view.rowSummaryLabel,
      view.columnSummaryLabel,
      theme.cellTextStyle,
      theme.headerTextStyle,
      theme.cellPadding,
      theme.minColumnWidth,
      theme.maxColumnWidth,
      theme.minRowHeaderWidth,
      theme.maxRowHeaderWidth,
      textScaler,
      textDirection,
    );
    final key = (layout, memoryKey);
    if (_widths != null && _widthsKey == key) return _widths!;
    final aggregate = shown;
    _widthsKey = key;
    final widths =
        ColumnWidthMeasurer(
          cellStyle: theme.cellTextStyle,
          headerStyle: theme.headerTextStyle,
          horizontalPadding: theme.cellPadding.horizontal + 1 + _slack,
          textDirection: textDirection,
          textScaler: textScaler,
        ).measure(
          layout: layout,
          headerColumns: headerColumns,
          aggregate: aggregate,
          aggregateLabel: aggregate == null
              ? ''
              : strings.aggregateLabel(aggregate, layout.facts),
          formatCell: (cell, value, _) =>
              (view.formatCell ?? _defaultFormat)(cell, value),
          rowLabel: (entry) => _entryText(entry, isRow: true),
          columnLabel: (entry) => _entryText(entry, isRow: false),
          titleLabel: (d) => strings.dimensionLabel(d, layout.facts),
          iconWidth: _iconWidth,
          measuredRows: view.measuredRows,
          minColumnWidth: theme.minColumnWidth,
          maxColumnWidth: theme.maxColumnWidth,
          minRowHeaderWidth: theme.minRowHeaderWidth,
          maxRowHeaderWidth: theme.maxRowHeaderWidth,
        );
    if (view.keepColumnWidths) _keepWidest(widths, memoryKey);
    return _widths = widths;
  }

  /// Raises each width to the widest remembered for that column and
  /// remembers the result.
  void _keepWidest(List<double> widths, Object memoryKey) {
    if (_memoryKey != memoryKey) {
      _rememberedHeader.clear();
      _rememberedData.clear();
      _memoryKey = memoryKey;
    }
    for (var c = 0; c < headerColumns; c++) {
      final id = c < rowDepth ? spec.rows.dimensions[c].dimension.id : '';
      widths[c] = math.max(widths[c], _rememberedHeader[id] ?? 0);
      _rememberedHeader[id] = widths[c];
    }
    final columns = layout.columns.entries;
    for (var j = 0; j < columns.length; j++) {
      final path = columns[j].path;
      final w = math.max(widths[headerColumns + j], _rememberedData[path] ?? 0);
      widths[headerColumns + j] = _rememberedData[path] = w;
    }
  }

  @override
  Widget build(BuildContext context) {
    final widths = _columnWidths(context);
    return TableView.builder(
      rowCount: headerRows + layout.rows.length,
      columnCount: headerColumns + layout.columns.length,
      pinnedRowCount: headerRows,
      pinnedColumnCount: headerColumns,
      columnBuilder: (index) =>
          TableSpan(extent: FixedTableSpanExtent(widths[index])),
      rowBuilder: (index) => TableSpan(
        extent: FixedTableSpanExtent(
          index < headerRows ? theme.headerRowHeight : theme.rowHeight,
        ),
      ),
      cellBuilder: (context, vicinity) {
        final r = vicinity.row, c = vicinity.column;
        if (r < headerRows && c < headerColumns) {
          return _corner(context, r, c);
        }
        if (r < headerRows) {
          return _columnHeader(context, r, c - headerColumns);
        }
        if (c < headerColumns) return _rowHeader(context, r - headerRows, c);
        return _dataCell(context, r - headerRows, c - headerColumns);
      },
    );
  }

  // ---------------------------------------------------------------- corner

  TableViewCell _corner(BuildContext context, int r, int c) {
    if (r < levelRows) {
      if (columnDepth == 0) {
        return TableViewCell(
          child: _box(color: theme.headerColor, child: const SizedBox()),
        );
      }
      return TableViewCell(
        columnMergeStart: headerColumns > 1 ? 0 : null,
        columnMergeSpan: headerColumns > 1 ? headerColumns : null,
        child: _titleCell(context, isRow: false, level: r),
      );
    }
    if (rowDepth == 0) {
      return TableViewCell(
        child: _box(color: theme.headerColor, child: const SizedBox()),
      );
    }
    return TableViewCell(child: _titleCell(context, isRow: true, level: c));
  }

  /// A dimension's title: tap sorts by value, the `▾` button, a long press
  /// or a secondary click open the level menu (see [_titleMenu]).
  Widget _titleCell(
    BuildContext context, {
    required bool isRow,
    required int level,
  }) {
    final axis = isRow ? spec.rows : spec.columns;
    final dimension = axis.dimensions[level];
    final sort = dimension.sort;
    return MenuAnchor(
      menuChildren: _titleMenu(context, isRow: isRow, level: level),
      builder: (context, menu, _) => InkWell(
        onTap: view.sortable
            ? () => _sortByValue(isRow: isRow, level: level)
            : null,
        onLongPress: menu.open,
        onSecondaryTapUp: (details) =>
            menu.open(position: details.localPosition),
        child: _box(
          color: theme.headerColor,
          alignment: isRow ? Alignment.centerLeft : Alignment.centerRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  strings.dimensionLabel(dimension.dimension, layout.facts),
                  style: theme.headerTextStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (sort.by == SortBy.value) _sortIcon(sort.direction),
              InkWell(
                onTap: () => menu.isOpen ? menu.close() : menu.open(),
                child: const Icon(Icons.arrow_drop_down, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Sort direction (when [CubeView.sortable]) and expand/collapse all for
  /// one level of an axis.
  List<Widget> _titleMenu(
    BuildContext context, {
    required bool isRow,
    required int level,
  }) {
    final axis = isRow ? spec.rows : spec.columns;
    final sort = axis.dimensions[level].sort;
    final entries = isRow ? layout.rows.entries : layout.columns.entries;
    final anyExpanded = entries.any(
      (e) => e.depth == level + 1 && e.isExpanded,
    );
    Widget check(bool on) => on ? const Icon(Icons.check) : const Icon(null);
    return [
      if (view.sortable) ...[
        for (final direction in SortDirection.values)
          MenuItemButton(
            leadingIcon: check(
              sort.by == SortBy.value && sort.direction == direction,
            ),
            onPressed: () =>
                _sortByValue(isRow: isRow, level: level, direction: direction),
            child: Text(
              direction == SortDirection.ascending
                  ? strings.sortAscending
                  : strings.sortDescending,
            ),
          ),
        const Divider(height: 1),
      ],
      MenuItemButton(
        leadingIcon: const Icon(Icons.unfold_more),
        onPressed: level < axis.depth - 1
            ? () => _expandLevel(context, isRow: isRow, level: level)
            : null,
        child: Text(strings.expandAll),
      ),
      MenuItemButton(
        leadingIcon: const Icon(Icons.unfold_less),
        onPressed: anyExpanded
            ? () => isRow
                  ? view.controller.collapseRowLevel(level)
                  : view.controller.collapseColumnLevel(level)
            : null,
        child: Text(strings.collapseAll),
      ),
    ];
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
          child: _entryLabel(context, entry, isRow: false),
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
            ? _entryLabel(context, owner, isRow: false)
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
          child: _entryLabel(context, entry, isRow: true),
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
            ? _entryLabel(context, owner, isRow: true)
            : const SizedBox(),
      ),
    );
  }

  /// A header entry's text: the summary label, the empty-group label or
  /// the formatted value.
  String _entryText(HeaderEntry entry, {required bool isRow}) => entry.isSummary
      ? (isRow ? view.rowSummaryLabel : view.columnSummaryLabel) ??
            strings.total
      : entry.value == null
      ? view.emptyGroupLabel ?? strings.emptyGroup
      : strings.formatValue(entry.dimension, entry.value);

  Widget _entryLabel(
    BuildContext context,
    HeaderEntry entry, {
    required bool isRow,
  }) {
    final text = _entryText(entry, isRow: isRow);
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
  }) => _confirmDialog(
    context,
    strings.largeExpansion(
      _entryText(entry, isRow: isRow),
      entry.childCount,
      isRow: isRow,
    ),
  );

  Future<bool> _confirmDialog(BuildContext context, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.largeExpansionTitle),
        content: Text(message),
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

  Future<void> _expandLevel(
    BuildContext context, {
    required bool isRow,
    required int level,
  }) async {
    final controller = view.controller;
    final cube = controller.cube;
    final added = isRow
        ? cube.rowsAddedByExpandingLevel(level)
        : cube.columnsAddedByExpandingLevel(level);
    if (added > view.expansionLimit) {
      final dimension =
          (isRow ? spec.rows : spec.columns).dimensions[level].dimension;
      final confirm = view.confirmLevelExpansion ?? _defaultConfirmLevel;
      if (!await confirm(context, dimension, added, isRow: isRow)) return;
    }
    if (isRow) {
      controller.expandRowLevel(level);
    } else {
      controller.expandColumnLevel(level);
    }
  }

  Future<bool> _defaultConfirmLevel(
    BuildContext context,
    Dimension dimension,
    int added, {
    required bool isRow,
  }) => _confirmDialog(
    context,
    strings.largeExpansion(
      strings.dimensionLabel(dimension, layout.facts),
      added,
      isRow: isRow,
    ),
  );

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

  /// Sorts [level] by value in [direction]; without one, ascending unless
  /// it already is (the tap toggle).
  void _sortByValue({
    required bool isRow,
    required int level,
    SortDirection? direction,
  }) {
    final axis = isRow ? spec.rows : spec.columns;
    final current = axis.dimensions[level].sort;
    direction ??=
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
