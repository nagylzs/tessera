import 'grid_metrics.dart';

/// One page of a paginated grid: the body rows `[rowStart, rowEnd)` and
/// body columns `[columnStart, columnEnd)` it shows. The frozen header
/// rows and header columns are drawn on every page in addition.
final class GridPage {
  const GridPage({
    required this.rowStart,
    required this.rowEnd,
    required this.columnStart,
    required this.columnEnd,
  });

  final int rowStart;
  final int rowEnd;
  final int columnStart;
  final int columnEnd;

  @override
  bool operator ==(Object other) =>
      other is GridPage &&
      other.rowStart == rowStart &&
      other.rowEnd == rowEnd &&
      other.columnStart == columnStart &&
      other.columnEnd == columnEnd;

  @override
  int get hashCode => Object.hash(rowStart, rowEnd, columnStart, columnEnd);

  @override
  String toString() =>
      'GridPage(rows $rowStart..$rowEnd, columns $columnStart..$columnEnd)';
}

/// Splits a grid laid out by [GridMetrics] into pages of a given body
/// size, breaking only on grid lines: the first [frozenRows] rows (the
/// header band) and [frozenColumns] columns (the row header) repeat on
/// every page, like a spreadsheet's print titles, and the rest is cut
/// into as many whole rows and columns as fit. A row or column larger
/// than the page still gets a page of its own. Pages run down first,
/// then across ([pages]); [rowBands] and [columnBands] are the cuts.
final class GridPagination {
  GridPagination._(this.rowBands, this.columnBands, this.pages);

  /// [width] and [height] are the space available for the grid on one
  /// page, in the metrics' units (divide by any scale first).
  factory GridPagination.of(
    GridMetrics metrics, {
    required int frozenRows,
    required int frozenColumns,
    required double width,
    required double height,
  }) {
    final rows = _bands(metrics.rowHeights, frozenRows, height);
    final columns = _bands(metrics.columnWidths, frozenColumns, width);
    return GridPagination._(rows, columns, [
      for (final (c0, c1) in columns)
        for (final (r0, r1) in rows)
          GridPage(rowStart: r0, rowEnd: r1, columnStart: c0, columnEnd: c1),
    ]);
  }

  /// `(start, end)` of the body rows on each page down.
  final List<(int, int)> rowBands;

  /// `(start, end)` of the body columns on each page across.
  final List<(int, int)> columnBands;

  /// Every page, down first, then across.
  final List<GridPage> pages;

  int get pageCount => pages.length;

  static List<(int, int)> _bands(List<double> sizes, int frozen, double space) {
    var available = space;
    for (var i = 0; i < frozen && i < sizes.length; i++) {
      available -= sizes[i];
    }
    if (frozen >= sizes.length) return [(frozen, frozen)];
    final out = <(int, int)>[];
    var start = frozen;
    while (start < sizes.length) {
      var end = start;
      var used = 0.0;
      while (end < sizes.length &&
          (end == start || used + sizes[end] <= available + 1e-9)) {
        used += sizes[end];
        end++;
      }
      out.add((start, end));
      start = end;
    }
    return out;
  }
}
