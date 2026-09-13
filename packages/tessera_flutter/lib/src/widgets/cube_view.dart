import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';
import 'package:tessera/tessera.dart';

import '../l10n/tessera_localizations.dart';
import 'cell_border.dart';
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
/// an aggregate name under a column sorts the rows by that value column
/// (tap again to flip). A level without a sort of its own follows the level
/// above ([AxisDimension.sort]); tapping a deeper level's name cycles
/// through the opposite direction, the same direction, and inheriting
/// again. Each dimension name also has a menu — the `▾` button, a long
/// press or a secondary click — with the sort direction, "same order as the
/// level above", and "expand all" / "collapse all" for that level. Cells are built lazily,
/// so large cubes stay cheap to scroll.
///
/// The current cell: tapping a data cell selects it (outlined, its row and
/// column headers tinted) and stores a [CellAddress] in
/// [CubeController.selection]; [CubeController.currentCell] gives the
/// cell with its facts, e.g. to chart them. The view takes focus on tap;
/// the arrow keys, Home/End (first/last column; with Ctrl first/last row)
/// and Page Up/Down move the current cell (kept scrolled into view), Enter
/// or Space toggles its row group, Escape clears the selection. `selectable: false` turns all of this off.
///
/// Column widths follow the content: the widest text of each column (its
/// values, labels and titles) is measured up front and the width clamped to
/// the [CubeTheme]'s bounds. Once widened, a column keeps its width for the
/// life of the view (see [keepColumnWidths]). Rows have a fixed height.
///
/// Every column entry has one value column per aggregate in [aggregates]
/// (the same layout the exporters write), so the aggregate names under a
/// column entry read "sum of total | count". Needs a [Material] ancestor.
class CubeView extends StatelessWidget {
  const CubeView({
    super.key,
    required this.controller,
    this.aggregates,
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
    this.selectable = true,
    this.focusNode,
    this.autofocus = false,
  });

  final CubeController controller;

  /// Which of the spec's aggregates to show, in this order, one value
  /// column per aggregate under each column entry. `null` shows every
  /// aggregate of the spec. Entries not in the spec (e.g. just removed)
  /// are skipped; with none left, cells stay blank.
  final List<Aggregate>? aggregates;

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

  /// Whether tapping a data cell makes it the current cell and the view
  /// takes keyboard focus (see the class comment).
  final bool selectable;

  /// Focus node of the grid; one is created when not given.
  final FocusNode? focusNode;

  final bool autofocus;

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

  final _vertical = ScrollController();
  final _horizontal = ScrollController();
  FocusNode? _ownFocusNode;
  FocusNode get _focusNode =>
      view.focusNode ?? (_ownFocusNode ??= FocusNode(debugLabel: 'CubeView'));

  /// Indices of the current cell in [layout] (entry and aggregate), or
  /// `-1`; set in [build] and before handling a key, so key repeats that
  /// arrive before the next frame see the selection they just moved.
  int _selectedRow = -1;
  int _selectedColumn = -1;
  int _selectedAggregate = -1;

  void _resolveSelection() {
    final selection = view.selectable ? view.controller.selection : null;
    _selectedRow = selection == null ? -1 : layout.rows.indexOf(selection.row);
    _selectedColumn = selection == null
        ? -1
        : layout.columns.indexOf(selection.column);
    // an address without an aggregate (or one no longer shown) means the
    // entry's first value column
    final a = selection?.aggregate;
    _selectedAggregate = a == null ? 0 : math.max(shown.indexOf(a), 0);
  }

  @override
  void dispose() {
    _vertical.dispose();
    _horizontal.dispose();
    _ownFocusNode?.dispose();
    super.dispose();
  }

  AxisGeometry? _rowGeometry;
  AxisGeometry? _columnGeometry;
  AxisGeometry get rowGeometry => _rowGeometry?.layout == layout.rows
      ? _rowGeometry!
      : _rowGeometry = AxisGeometry(layout.rows);
  AxisGeometry get columnGeometry => _columnGeometry?.layout == layout.columns
      ? _columnGeometry!
      : _columnGeometry = AxisGeometry(layout.columns);

  CubeSpec get spec => layout.spec;

  /// The aggregates actually displayed (see [CubeView.aggregates]).
  List<Aggregate> get shown {
    final wanted = view.aggregates;
    if (wanted == null) return spec.aggregates;
    return [
      for (final a in wanted)
        if (spec.aggregates.contains(a)) a,
    ];
  }

  /// Grid columns per column entry.
  int get perEntry => math.max(shown.length, 1);

  /// Grid column (0-based among the data columns) of column entry [j]'s
  /// [a]-th aggregate.
  int _dataColumn(int j, int a) => j * perEntry + a;
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
  /// column (by path and aggregate) under [_memoryKey]; see
  /// [CubeView.keepColumnWidths].
  final _rememberedHeader = <String, double>{};
  final _rememberedData = <(DimensionPath, Aggregate?), double>{};
  Object? _memoryKey;

  /// One width per grid column, measured from the content of [layout] and
  /// recomputed only when something that affects it changes.
  List<double> _columnWidths(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    // Measure with the styles as Text renders them: merged onto the
    // ambient DefaultTextStyle, which supplies the font family (and size)
    // a theme style may leave unset.
    final defaultStyle = DefaultTextStyle.of(context).style;
    final cellStyle = defaultStyle.merge(theme.cellTextStyle);
    final headerStyle = defaultStyle.merge(theme.headerTextStyle);
    final memoryKey = (
      Object.hashAll(shown),
      strings,
      view.formatCell,
      view.measuredRows,
      view.emptyGroupLabel,
      view.rowSummaryLabel,
      view.columnSummaryLabel,
      cellStyle,
      headerStyle,
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
    _widthsKey = key;
    final widths =
        ColumnWidthMeasurer(
          cellStyle: cellStyle,
          headerStyle: headerStyle,
          horizontalPadding: theme.cellPadding.horizontal + 1 + _slack,
          textDirection: textDirection,
          textScaler: textScaler,
        ).measure(
          layout: layout,
          headerColumns: headerColumns,
          aggregates: shown,
          aggregateLabel: (a) => strings.aggregateLabel(a, layout.facts),
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
    final aggregates = shown;
    for (var j = 0; j < columns.length; j++) {
      for (var a = 0; a < perEntry; a++) {
        final key = (
          columns[j].path,
          a < aggregates.length ? aggregates[a] : null,
        );
        final c = headerColumns + _dataColumn(j, a);
        final w = math.max(widths[c], _rememberedData[key] ?? 0);
        widths[c] = _rememberedData[key] = w;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final widths = _columnWidths(context);
    _resolveSelection();
    return Focus(
      focusNode: _focusNode,
      autofocus: view.autofocus && view.selectable,
      canRequestFocus: view.selectable,
      onKeyEvent: view.selectable ? _onKey : null,
      child: _table(widths),
    );
  }

  Widget _table(List<double> widths) {
    // Header icons (the only icons in the grid) take the theme's colour;
    // the title menus open in an overlay and keep the app's.
    return IconTheme.merge(
      data: IconThemeData(color: theme.headerIconColor),
      child: _tableView(widths),
    );
  }

  Widget _tableView(List<double> widths) {
    return TableView.builder(
      verticalDetails: ScrollableDetails.vertical(controller: _vertical),
      horizontalDetails: ScrollableDetails.horizontal(controller: _horizontal),
      rowCount: headerRows + layout.rows.length,
      columnCount: headerColumns + layout.columns.length * perEntry,
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
        final d = c - headerColumns;
        if (r < headerRows) {
          return _columnHeader(context, r, d ~/ perEntry, d % perEntry);
        }
        if (c < headerColumns) return _rowHeader(context, r - headerRows, c);
        return _dataCell(context, r - headerRows, d ~/ perEntry, d % perEntry);
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
    final sort = axis.sortAt(level);
    return MenuAnchor(
      menuChildren: _titleMenu(context, isRow: isRow, level: level),
      builder: (context, menu, _) => InkWell(
        onTap: view.sortable
            ? () => _setSort(
                isRow: isRow,
                level: level,
                sort: _nextTapSort(axis, level),
              )
            : null,
        onLongPress: menu.open,
        onSecondaryTapUp: (details) =>
            menu.open(position: details.localPosition),
        child: _box(
          color: theme.headerLevelColor(_headerLevel(isRow, level)),
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
              if (sort.by == SortBy.value)
                _sortIcon(
                  sort.direction,
                  faded: level > 0 && dimension.sort == null,
                ),
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

  /// Sort direction (when [CubeView.sortable]; deeper levels can also
  /// inherit the level above) and expand/collapse all for one level of an
  /// axis.
  List<Widget> _titleMenu(
    BuildContext context, {
    required bool isRow,
    required int level,
  }) {
    final axis = isRow ? spec.rows : spec.columns;
    final own = axis.dimensions[level].sort;
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
              own != null &&
                  own.by == SortBy.value &&
                  own.direction == direction,
            ),
            onPressed: () => _setSort(
              isRow: isRow,
              level: level,
              sort: AxisSort(
                direction: direction,
                nulls: axis.sortAt(level).nulls,
              ),
            ),
            child: Text(
              direction == SortDirection.ascending
                  ? strings.sortAscending
                  : strings.sortDescending,
            ),
          ),
        if (level > 0)
          MenuItemButton(
            leadingIcon: check(own == null),
            onPressed: () => _setSort(isRow: isRow, level: level, sort: null),
            child: Text(strings.inheritSort),
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

  /// [faded] marks a direction inherited from the level above.
  Widget _sortIcon(SortDirection direction, {bool faded = false}) {
    final icon = Icon(
      direction == SortDirection.ascending
          ? Icons.arrow_upward
          : Icons.arrow_downward,
      size: 12,
    );
    return faded ? Opacity(opacity: 0.4, child: icon) : icon;
  }

  // --------------------------------------------------------- column header

  /// Header cell of column entry [j]'s [a]-th value column.
  TableViewCell _columnHeader(BuildContext context, int r, int j, int a) {
    final entry = layout.columns.entries[j];
    final aggregates = shown;
    if (r == levelRows) {
      final aggregate = a < aggregates.length ? aggregates[a] : null;
      final isKey = aggregate != null && _isSortKeyColumn(entry, aggregate);
      return TableViewCell(
        child: _box(
          color: entry.isSummary
              ? theme.summaryColor
              : theme.headerLevelColor(_headerLevel(false, entry.depth - 1)),
          alignment: Alignment.centerRight,
          onTap: view.sortable && aggregate != null
              ? () => _sortRowsByColumn(entry, aggregate)
              : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  aggregate == null
                      ? ''
                      : strings.aggregateLabel(aggregate, layout.facts),
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
    // Group labels span the entry's value columns; a merged cell is built
    // once, from its first grid column.
    final mergeStart = headerColumns + _dataColumn(j, 0);
    if (columnDepth == 0) {
      return TableViewCell(
        columnMergeStart: perEntry > 1 ? mergeStart : null,
        columnMergeSpan: perEntry > 1 ? perEntry : null,
        child: _box(
          color: theme.summaryColor,
          alignment: Alignment.topLeft,
          child: _entryLabel(context, entry, isRow: false),
        ),
      );
    }
    final area = columnGeometry.areaAt(r, j);
    final owner = layout.columns.entryFor(area.path)!;
    final span = area.entrySpan * perEntry;
    return TableViewCell(
      rowMergeStart: area.levelSpan > 1 ? area.levelStart : null,
      rowMergeSpan: area.levelSpan > 1 ? area.levelSpan : null,
      columnMergeStart: span > 1
          ? headerColumns + _dataColumn(area.entryStart, 0)
          : null,
      columnMergeSpan: span > 1 ? span : null,
      child: _box(
        // the label and, when expanded, its leg: the whole rotated L
        color: _headerColor(
          owner,
          isRow: false,
          selected: area.entryIndex == _selectedColumn,
        ),
        alignment: Alignment.topLeft,
        // an expanded group's label and the leg below it form one area
        bottomBorderFrom: _legAt(area) == 0 ? _entryWidth(area.entryStart) : 0,
        bottomBorderUntil: _legAt(area) == area.entrySpan - 1
            ? _spanWidth(area, area.entrySpan - 1)
            : double.infinity,
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
    final owner = layout.rows.entryFor(area.path)!;
    return TableViewCell(
      columnMergeStart: area.levelSpan > 1 ? area.levelStart : null,
      columnMergeSpan: area.levelSpan > 1 ? area.levelSpan : null,
      rowMergeStart: area.entrySpan > 1 ? headerRows + area.entryStart : null,
      rowMergeSpan: area.entrySpan > 1 ? area.entrySpan : null,
      child: _box(
        color: _headerColor(
          owner,
          isRow: true,
          selected: area.entryIndex == _selectedRow,
        ),
        alignment: Alignment.topLeft,
        // an expanded group's label and the leg beside it form one area
        rightBorderFrom: _legAt(area) == 0 ? theme.rowHeight : 0,
        rightBorderUntil: _legAt(area) == area.entrySpan - 1
            ? (area.entrySpan - 1) * theme.rowHeight
            : double.infinity,
        child: area.isLabel
            ? _entryLabel(context, owner, isRow: true)
            : const SizedBox(),
      ),
    );
  }

  /// Position of the group's own row/column within a merged label area
  /// (`0` first, `entrySpan - 1` last), or `-1` when the area is not a
  /// multi-entry label or the group has no row of its own.
  static int _legAt(HeaderArea area) =>
      area.isLabel && area.entrySpan > 1 && area.entryIndex >= 0
      ? area.entryIndex - area.entryStart
      : -1;

  /// Total width of the first [count] data columns of [area]'s span.
  double _spanWidth(HeaderArea area, int count) {
    var w = 0.0;
    for (var k = 0; k < count; k++) {
      w += _entryWidth(area.entryStart + k);
    }
    return w;
  }

  /// Width of column entry [j]: its value columns together.
  double _entryWidth(int j) {
    var w = 0.0;
    for (var a = 0; a < perEntry; a++) {
      w += _widths![headerColumns + _dataColumn(j, a)];
    }
    return w;
  }

  HeaderLevel _headerLevel(bool isRow, int level) => HeaderLevel(
    isRow: isRow,
    level: level,
    rowLevels: rowDepth,
    columnLevels: columnDepth,
  );

  /// Header background: the summary colour or the level's header colour,
  /// tinted with the selection colour for the current cell's row/column
  /// label.
  Color _headerColor(
    HeaderEntry entry, {
    required bool isRow,
    required bool selected,
  }) {
    final base = entry.isSummary
        ? theme.summaryColor
        : theme.headerLevelColor(_headerLevel(isRow, entry.depth - 1));
    return selected
        ? Color.alphaBlend(theme.selectionColor.withValues(alpha: 0.15), base)
        : base;
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

  /// Data cell of row entry [i] × column entry [j], [a]-th aggregate.
  TableViewCell _dataCell(BuildContext context, int i, int j, int a) {
    final rowEntry = layout.rows.entries[i];
    final colEntry = layout.columns.entries[j];
    final cell = layout.cellAt(i, j);
    final summary = rowEntry.isSummary || colEntry.isSummary;
    // Non-summary cells have both depths >= 1; levels count from 0.
    var color = summary
        ? theme.summaryColor
        : theme.levelColor(
            CellLevel(
              row: rowEntry.depth - 1,
              column: colEntry.depth - 1,
              rowLevels: rowDepth,
              columnLevels: columnDepth,
            ),
          );
    final aggregates = shown;
    final aggregate = a < aggregates.length ? aggregates[a] : null;
    if (aggregate != null && _isSortKeyColumn(colEntry, aggregate)) {
      color = Color.alphaBlend(theme.sortKeyColor, color);
    }
    Widget child = const SizedBox();
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
    final selected =
        i == _selectedRow && j == _selectedColumn && a == _selectedAggregate;
    return TableViewCell(
      child: Semantics(
        selected: selected,
        child: _box(
          color: color,
          alignment: Alignment.centerRight,
          onTap: !view.selectable && onTap == null
              ? null
              : () {
                  if (view.selectable) {
                    _focusNode.requestFocus();
                    view.controller.selection = CellAddress(
                      row: rowEntry.path,
                      column: colEntry.path,
                      aggregate: aggregate,
                    );
                  }
                  onTap?.call(cell);
                },
          outline: selected ? theme.selectionColor : null,
          child: child,
        ),
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

  /// A cell: background, padding and its right/bottom hairlines (see
  /// [CellBorder] for [rightBorderFrom] / [bottomBorderFrom]).
  Widget _box({
    required Color color,
    required Widget child,
    Alignment alignment = Alignment.centerLeft,
    VoidCallback? onTap,
    double rightBorderFrom = 0,
    double rightBorderUntil = double.infinity,
    double bottomBorderFrom = 0,
    double bottomBorderUntil = double.infinity,
    Color? outline,
  }) {
    final box = CustomPaint(
      foregroundPainter: CellBorder(
        color: theme.borderColor,
        rightFrom: rightBorderFrom,
        rightUntil: rightBorderUntil,
        bottomFrom: bottomBorderFrom,
        bottomUntil: bottomBorderUntil,
        outline: outline,
      ),
      child: Container(
        color: color,
        padding: theme.cellPadding + const EdgeInsets.only(right: 1, bottom: 1),
        alignment: alignment,
        child: child,
      ),
    );
    return onTap == null ? box : InkWell(onTap: onTap, child: box);
  }

  // -------------------------------------------------------------- keyboard

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final rows = layout.rows.length, columns = layout.columns.length;
    if (rows == 0 || columns == 0) return KeyEventResult.ignored;
    // the page size in rows: what fits under the header band
    final page = _vertical.hasClients
        ? math.max(
            1,
            ((_vertical.position.viewportDimension -
                        headerRows * theme.headerRowHeight) /
                    theme.rowHeight)
                .floor(),
          )
        : 10;
    _resolveSelection();
    final key = _navigationKey(event);
    if (key == LogicalKeyboardKey.escape) {
      view.controller.selection = null;
      return KeyEventResult.handled;
    }
    // horizontal movement walks the value columns: entry × aggregate
    final dataColumns = columns * perEntry;
    final i = _selectedRow < 0 ? 0 : _selectedRow;
    final d = _selectedColumn < 0
        ? 0
        : _dataColumn(_selectedColumn, _selectedAggregate);
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    final (int, int)? target = switch (key) {
      LogicalKeyboardKey.arrowUp => (i - 1, d),
      LogicalKeyboardKey.arrowDown => (i + 1, d),
      LogicalKeyboardKey.arrowLeft => (i, d - 1),
      LogicalKeyboardKey.arrowRight => (i, d + 1),
      LogicalKeyboardKey.home => ctrl ? (0, d) : (i, 0),
      LogicalKeyboardKey.end => ctrl ? (rows - 1, d) : (i, dataColumns - 1),
      LogicalKeyboardKey.pageUp => (i - page, d),
      LogicalKeyboardKey.pageDown => (i + page, d),
      _ => null,
    };
    if (target != null) {
      // with nothing selected, any movement key selects the first cell
      final (ti, td) = _selectedRow < 0 || _selectedColumn < 0
          ? (0, 0)
          : (target.$1.clamp(0, rows - 1), target.$2.clamp(0, dataColumns - 1));
      final tj = td ~/ perEntry, ta = td % perEntry;
      final aggregates = shown;
      view.controller.selection = CellAddress(
        row: layout.rows.entries[ti].path,
        column: layout.columns.entries[tj].path,
        aggregate: ta < aggregates.length ? aggregates[ta] : null,
      );
      _scrollIntoView(ti, td);
      return KeyEventResult.handled;
    }
    if ((key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter ||
            key == LogicalKeyboardKey.space) &&
        _selectedRow >= 0) {
      final entry = layout.rows.entries[_selectedRow];
      if (entry.isExpandable) _toggle(context, entry, isRow: true);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// The logical key of [event], with the number block's navigation keys
  /// (Home, arrows, Page Up …, sent as `numpad7` etc. without a character
  /// while NumLock is off — Flutter does not tell them apart otherwise)
  /// translated to their main-keyboard counterparts.
  static LogicalKeyboardKey _navigationKey(KeyEvent event) {
    final key = event.logicalKey;
    if (event.character?.isNotEmpty ?? false) return key;
    return _numpadNavigation[key] ?? key;
  }

  static final _numpadNavigation = {
    LogicalKeyboardKey.numpad1: LogicalKeyboardKey.end,
    LogicalKeyboardKey.numpad2: LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.numpad3: LogicalKeyboardKey.pageDown,
    LogicalKeyboardKey.numpad4: LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.numpad6: LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.numpad7: LogicalKeyboardKey.home,
    LogicalKeyboardKey.numpad8: LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.numpad9: LogicalKeyboardKey.pageUp,
  };

  /// Scrolls so that the data cell at row [i], grid data column [d] is not
  /// hidden by the viewport edges or the pinned headers. Every extent is
  /// fixed, so the offsets are arithmetic on the row heights and
  /// [_widths].
  void _scrollIntoView(int i, int d) {
    final widths = _widths;
    if (widths == null) return;
    if (_vertical.hasClients) {
      final pinned = headerRows * theme.headerRowHeight;
      _reveal(
        _vertical,
        pinned: pinned,
        start: pinned + i * theme.rowHeight,
        extent: theme.rowHeight,
      );
    }
    if (_horizontal.hasClients) {
      var pinned = 0.0;
      for (var c = 0; c < headerColumns; c++) {
        pinned += widths[c];
      }
      var start = pinned;
      for (var c = 0; c < d; c++) {
        start += widths[headerColumns + c];
      }
      _reveal(
        _horizontal,
        pinned: pinned,
        start: start,
        extent: widths[headerColumns + d],
      );
    }
  }

  static void _reveal(
    ScrollController controller, {
    required double pinned,
    required double start,
    required double extent,
  }) {
    final position = controller.position;
    final offset = position.pixels;
    final viewport = position.viewportDimension;
    double? target;
    if (start - pinned < offset) {
      target = start - pinned;
    } else if (start + extent > offset + viewport) {
      target = start + extent - viewport;
    }
    if (target != null) {
      controller.jumpTo(
        target.clamp(position.minScrollExtent, position.maxScrollExtent),
      );
    }
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

  /// Whether [column]'s [aggregate] value column is what the rows are
  /// sorted by.
  bool _isSortKeyColumn(HeaderEntry column, Aggregate aggregate) {
    for (var i = 0; i < spec.rows.depth; i++) {
      final s = spec.rows.sortAt(i);
      if (s.by != SortBy.aggregate || s.aggregate != aggregate) continue;
      final key = s.keyPath;
      if (key == null ? column.isSummary : key == column.path) return true;
    }
    return false;
  }

  SortDirection _rowSortDirection() {
    for (var i = 0; i < spec.rows.depth; i++) {
      final s = spec.rows.sortAt(i);
      if (s.by == SortBy.aggregate) return s.direction;
    }
    return SortDirection.ascending;
  }

  /// The sort a tap on [level]'s title gives. The first level toggles
  /// between ascending and descending. A deeper level cycles through three
  /// states: the direction opposite to the one it inherits (so the first
  /// tap is visible), the same direction set explicitly, then inheriting
  /// the level above again (`null`).
  AxisSort? _nextTapSort(CubeAxis axis, int level) {
    final effective = axis.sortAt(level);
    AxisSort value(SortDirection d) =>
        AxisSort(direction: d, nulls: effective.nulls);
    if (level == 0) {
      return value(
        effective.by == SortBy.value &&
                effective.direction == SortDirection.ascending
            ? SortDirection.descending
            : SortDirection.ascending,
      );
    }
    final own = axis.dimensions[level].sort;
    final inherited = axis.sortAt(level - 1);
    final first =
        inherited.by == SortBy.value &&
            inherited.direction == SortDirection.descending
        ? SortDirection.ascending
        : SortDirection.descending;
    if (own == null || own.by != SortBy.value) return value(first);
    if (own.direction == first) {
      return value(
        first == SortDirection.ascending
            ? SortDirection.descending
            : SortDirection.ascending,
      );
    }
    return null;
  }

  /// Gives [level] its own [sort] (`null` = inherit the level above).
  void _setSort({
    required bool isRow,
    required int level,
    required AxisSort? sort,
  }) {
    final axis = isRow ? spec.rows : spec.columns;
    final dims = List.of(axis.dimensions);
    dims[level] = AxisDimension(dims[level].dimension, sort: sort);
    _updateAxis(
      isRow: isRow,
      axis: axis.copyWith(dimensions: dims),
    );
  }

  /// Sorts the first row level by [column]'s [aggregate] (tap again to
  /// flip) and lets the deeper levels inherit it.
  void _sortRowsByColumn(HeaderEntry column, Aggregate aggregate) {
    if (spec.rows.depth == 0) return;
    final keyPath = column.isSummary ? null : column.path;
    final first = spec.rows.sortAt(0);
    final same =
        first.by == SortBy.aggregate &&
        first.aggregate == aggregate &&
        first.keyPath == keyPath;
    final direction = same && first.direction == SortDirection.descending
        ? SortDirection.ascending
        : SortDirection.descending;
    final dims = [
      for (final (i, d) in spec.rows.dimensions.indexed)
        AxisDimension(
          d.dimension,
          sort: i == 0
              ? AxisSort(
                  by: SortBy.aggregate,
                  aggregate: aggregate,
                  keyPath: keyPath,
                  direction: direction,
                  nulls: first.nulls,
                )
              : null,
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
