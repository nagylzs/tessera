import 'dart:math' as math;

import '../cube/aggregate.dart';
import '../cube/axis_geometry.dart';
import '../cube/cube_layout.dart';
import '../cube/dimension_path.dart';
import '../l10n/tessera_strings.dart';

/// What a [GridCell] is, so a renderer can style it.
enum GridCellKind {
  /// Unused corner cell.
  blank,

  /// A column dimension's name in the corner (one per column level).
  columnTitle,

  /// A row dimension's name in the corner (one per row level).
  rowTitle,

  /// A column group's label (or the blank leg on the group's own column).
  columnLabel,

  /// A row group's label (or the blank leg on the group's own row).
  rowLabel,

  /// An aggregate's name under a column entry.
  aggregateLabel,

  /// A value.
  data,
}

/// One cell of a [CubeGrid].
///
/// Merged areas (an expanded group's label over its subtree, a
/// dimension title across the header columns, a column entry across its
/// aggregates) are represented by an *origin* cell carrying [rowSpan] /
/// [columnSpan] and *covered* cells pointing back at it with
/// [originRow] / [originColumn]. Covered cells repeat the area's [value],
/// so a flat renderer can either blank them or fill the group down.
final class GridCell {
  const GridCell({
    required this.kind,
    this.value,
    this.path,
    this.isSummary = false,
    this.isLeg = false,
    this.level = -1,
    this.rowLevel = -1,
    this.columnLevel = -1,
    this.rowSpan = 1,
    this.columnSpan = 1,
    this.originRow,
    this.originColumn,
    this.alignRight = false,
  });

  final GridCellKind kind;

  /// Label text, a number, a bool, a [DateTime] or `null` (blank).
  final Object? value;

  /// The group a header cell belongs to (`null` for titles and data).
  final DimensionPath? path;

  /// On the summary row/column (headers and data alike).
  final bool isSummary;

  /// The blank leg of an expanded group's area (its own row/column below
  /// the label); never carries a value.
  final bool isLeg;

  /// Data cells: row depth + column depth, from `0`; `-1` otherwise.
  /// See [rowLevel] and [columnLevel] for the two parts.
  final int level;

  /// The row level (index of the row dimension, from `0`) a cell belongs
  /// to: the row group's depth for data cells and row labels, the column
  /// position for row titles; `-1` on summary rows and for cells of the
  /// column header band.
  final int rowLevel;

  /// The column level the cell belongs to, likewise: the column group's
  /// depth for data cells, column labels and aggregate labels, the row
  /// position for column titles; `-1` on the summary column and in the
  /// row header.
  final int columnLevel;

  final int rowSpan;
  final int columnSpan;

  /// Set on covered cells: where the area's origin is.
  final int? originRow;
  final int? originColumn;

  bool get isOrigin => originRow == null;
  bool get isMerged => rowSpan > 1 || columnSpan > 1;

  /// Numbers, aggregate names and column titles read best right-aligned.
  final bool alignRight;

  @override
  String toString() =>
      'GridCell(${kind.name}${isSummary ? ', summary' : ''}'
      '${isLeg ? ', leg' : ''}: $value'
      '${isMerged ? ', $rowSpan×$columnSpan' : ''}'
      '${isOrigin ? '' : ', covered by ($originRow,$originColumn)'})';
}

/// A [CubeLayout] laid out as a rectangular grid the way `CubeView` shows
/// it: one header row per column dimension plus the aggregate-label row,
/// one header column per row dimension, an expanded group's label merged
/// over its subtree in the "rotated L" shape (via [AxisGeometry]), each
/// column entry spanning one column per aggregate, subtotals on the
/// group's own row/column, labels from [TesseraStrings].
///
/// Exporters (CSV in this package, XLSX in `tessera_xlsx`, …) render from
/// this rather than each walking the layout.
final class CubeGrid {
  CubeGrid._(
    this.layout,
    this.aggregates,
    this.headerRows,
    this.headerColumns,
    this._cells,
  );

  /// [aggregates] selects and orders the value columns under each column
  /// entry (default: every aggregate of the spec; each must be in the
  /// spec). The label overrides work as on `CubeView`.
  factory CubeGrid.of(
    CubeLayout layout, {
    required TesseraStrings strings,
    List<Aggregate>? aggregates,
    String? emptyGroupLabel,
    String? rowSummaryLabel,
    String? columnSummaryLabel,
  }) {
    final aggs = aggregates ?? layout.spec.aggregates;
    for (final a in aggs) {
      if (!layout.spec.aggregates.contains(a)) {
        throw ArgumentError.value(a.id, 'aggregates', 'not in the spec');
      }
    }
    return _Builder(
      layout,
      aggs,
      strings,
      emptyGroupLabel,
      rowSummaryLabel,
      columnSummaryLabel,
    ).build();
  }

  final CubeLayout layout;
  final List<Aggregate> aggregates;

  /// Header band height: one row per column dimension (at least one) plus
  /// the aggregate-label row.
  final int headerRows;

  /// Row header width: one column per row dimension, at least one.
  final int headerColumns;

  final List<List<GridCell>> _cells;

  int get rowCount => _cells.length;
  int get columnCount => _cells.isEmpty ? 0 : _cells.first.length;

  /// Grid columns per column entry.
  int get columnsPerEntry => math.max(aggregates.length, 1);

  GridCell cellAt(int row, int column) => _cells[row][column];

  List<GridCell> row(int row) => _cells[row];
}

final class _Builder {
  _Builder(
    this.layout,
    this.aggregates,
    this.strings,
    this.emptyGroupLabel,
    this.rowSummaryLabel,
    this.columnSummaryLabel,
  ) : rowGeometry = AxisGeometry(layout.rows),
      columnGeometry = AxisGeometry(layout.columns);

  final CubeLayout layout;
  final List<Aggregate> aggregates;
  final TesseraStrings strings;
  final String? emptyGroupLabel;
  final String? rowSummaryLabel;
  final String? columnSummaryLabel;
  final AxisGeometry rowGeometry;
  final AxisGeometry columnGeometry;

  int get rowDepth => layout.spec.rows.depth;
  int get columnDepth => layout.spec.columns.depth;
  int get perEntry => math.max(aggregates.length, 1);
  int get headerColumns => math.max(rowDepth, 1);
  int get levelRows => math.max(columnDepth, 1);
  int get headerRows => levelRows + 1;

  late final List<List<GridCell>> cells;

  CubeGrid build() {
    final rows = layout.rows.entries;
    final columns = layout.columns.entries;
    final rowCount = headerRows + rows.length;
    final columnCount = headerColumns + columns.length * perEntry;
    cells = [
      for (var r = 0; r < rowCount; r++)
        List<GridCell>.filled(
          columnCount,
          const GridCell(kind: GridCellKind.blank),
        ),
    ];
    _corner();
    _columnHeaders(columns);
    _rowHeaders(rows);
    _data(rows, columns);
    return CubeGrid._(layout, aggregates, headerRows, headerColumns, cells);
  }

  /// Fills a merged area: the origin cell with spans, covered cells
  /// pointing at it (and repeating the value).
  void _area(
    int row,
    int column,
    int rowSpan,
    int columnSpan,
    GridCell origin,
  ) {
    cells[row][column] = GridCell(
      kind: origin.kind,
      value: origin.value,
      path: origin.path,
      isSummary: origin.isSummary,
      isLeg: origin.isLeg,
      level: origin.level,
      rowLevel: origin.rowLevel,
      columnLevel: origin.columnLevel,
      rowSpan: rowSpan,
      columnSpan: columnSpan,
      alignRight: origin.alignRight,
    );
    for (var r = row; r < row + rowSpan; r++) {
      for (var c = column; c < column + columnSpan; c++) {
        if (r == row && c == column) continue;
        cells[r][c] = GridCell(
          kind: origin.kind,
          value: origin.value,
          path: origin.path,
          isSummary: origin.isSummary,
          isLeg: origin.isLeg,
          level: origin.level,
          rowLevel: origin.rowLevel,
          columnLevel: origin.columnLevel,
          originRow: row,
          originColumn: column,
          alignRight: origin.alignRight,
        );
      }
    }
  }

  void _corner() {
    for (var r = 0; r < levelRows; r++) {
      if (columnDepth == 0) continue; // blank
      _area(
        r,
        0,
        1,
        headerColumns,
        GridCell(
          kind: GridCellKind.columnTitle,
          value: strings.dimensionLabel(
            layout.spec.columns.dimensions[r].dimension,
            layout.facts,
          ),
          columnLevel: r,
          alignRight: true,
        ),
      );
    }
    for (var c = 0; c < headerColumns; c++) {
      cells[levelRows][c] = rowDepth == 0
          ? const GridCell(kind: GridCellKind.blank)
          : GridCell(
              kind: GridCellKind.rowTitle,
              value: strings.dimensionLabel(
                layout.spec.rows.dimensions[c].dimension,
                layout.facts,
              ),
              rowLevel: c,
            );
    }
  }

  void _columnHeaders(List<HeaderEntry> columns) {
    for (var j = 0; j < columns.length; j++) {
      final entry = columns[j];
      final start = headerColumns + j * perEntry;
      for (var a = 0; a < perEntry; a++) {
        cells[levelRows][start + a] = GridCell(
          kind: GridCellKind.aggregateLabel,
          value: aggregates.isEmpty
              ? null
              : strings.aggregateLabel(aggregates[a], layout.facts),
          path: entry.path,
          isSummary: entry.isSummary,
          columnLevel: entry.depth - 1,
          alignRight: true,
        );
      }
      if (columnDepth == 0) {
        _area(
          0,
          start,
          1,
          perEntry,
          GridCell(
            kind: GridCellKind.columnLabel,
            value: _entryText(entry, isRow: false),
            path: entry.path,
            isSummary: true,
          ),
        );
        continue;
      }
      for (var level = 0; level < columnDepth; level++) {
        final area = columnGeometry.areaAt(level, j);
        if (area.levelStart != level || area.entryStart != j) continue;
        final owner = layout.columns.entryFor(area.path)!;
        _area(
          level,
          start,
          area.levelSpan,
          area.entrySpan * perEntry,
          GridCell(
            kind: GridCellKind.columnLabel,
            value: area.isLabel ? _entryText(owner, isRow: false) : null,
            path: area.path,
            isSummary: owner.isSummary,
            isLeg: !area.isLabel,
            columnLevel: owner.depth - 1,
          ),
        );
      }
    }
  }

  void _rowHeaders(List<HeaderEntry> rows) {
    for (var i = 0; i < rows.length; i++) {
      final entry = rows[i];
      final gridRow = headerRows + i;
      if (rowDepth == 0) {
        cells[gridRow][0] = GridCell(
          kind: GridCellKind.rowLabel,
          value: _entryText(entry, isRow: true),
          path: entry.path,
          isSummary: true,
        );
        continue;
      }
      for (var level = 0; level < rowDepth; level++) {
        final area = rowGeometry.areaAt(level, i);
        if (area.levelStart != level || area.entryStart != i) continue;
        final owner = layout.rows.entryFor(area.path)!;
        _area(
          gridRow,
          level,
          area.entrySpan,
          area.levelSpan,
          GridCell(
            kind: GridCellKind.rowLabel,
            value: area.isLabel ? _entryText(owner, isRow: true) : null,
            path: area.path,
            isSummary: owner.isSummary,
            isLeg: !area.isLabel,
            rowLevel: owner.depth - 1,
          ),
        );
      }
    }
  }

  void _data(List<HeaderEntry> rows, List<HeaderEntry> columns) {
    for (var i = 0; i < rows.length; i++) {
      for (var j = 0; j < columns.length; j++) {
        final summary = rows[i].isSummary || columns[j].isSummary;
        final level = rows[i].depth + columns[j].depth - 2;
        final cell = layout.cellAt(i, j);
        for (var a = 0; a < perEntry; a++) {
          final value = cell.isEmpty || aggregates.isEmpty
              ? null
              : cell.aggregate<Object?>(aggregates[a]);
          cells[headerRows + i][headerColumns + j * perEntry + a] = GridCell(
            kind: GridCellKind.data,
            value: value,
            isSummary: summary,
            level: summary ? -1 : level,
            rowLevel: rows[i].depth - 1,
            columnLevel: columns[j].depth - 1,
            alignRight: true,
          );
        }
      }
    }
  }

  String _entryText(HeaderEntry entry, {required bool isRow}) => entry.isSummary
      ? (isRow ? rowSummaryLabel : columnSummaryLabel) ?? strings.total
      : entry.value == null
      ? emptyGroupLabel ?? strings.emptyGroup
      : strings.formatValue(entry.dimension, entry.value);
}
