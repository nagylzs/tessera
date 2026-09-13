import 'package:test/test.dart';
import 'package:tessera/tessera.dart';

const region = ColumnDimension('region');
const qty = Measure('qty');

Future<FactTable> facts(int rows) async {
  final source = ListDataSource(
    columns: ['region', 'qty'],
    rows: [
      for (var i = 0; i < rows; i++) ['R${i.toString().padLeft(3, '0')}', i],
    ],
    declaredSchema: Schema([
      const ColumnSpec(name: 'region', type: ColumnType.text),
      const ColumnSpec(name: 'qty', type: ColumnType.number),
    ]),
  );
  return (await loadFacts(source)).facts;
}

void main() {
  test('bands cut on grid lines, headers repeat, down then across', () async {
    final f = await facts(10);
    final grid = CubeGrid.of(
      Cube(
        facts: f,
        spec: CubeSpec(
          rows: CubeAxis.of([region]),
          aggregates: [
            Aggregate.sum(qty),
            Aggregate.count,
            Aggregate.average(qty),
            Aggregate.min(qty),
            Aggregate.max(qty),
            Aggregate.countNonNull(qty),
          ],
        ),
      ).layout,
      strings: const TesseraStringsEn(),
    );
    // header: 1 row (no column dims) + aggregate row = 2; 1 header column
    expect(grid.headerRows, 2);
    expect(grid.headerColumns, 1);
    expect(grid.rowCount, 2 + 11); // 10 regions + Σ
    expect(grid.columnCount, 1 + 6);
    final m = GridMetrics.of(
      grid,
      theme: const CubeExportTheme(),
      text: (c) => c.value?.toString() ?? '',
      minColumnWidth: 100,
      maxColumnWidth: 100,
      minHeaderColumnWidth: 100,
      maxHeaderColumnWidth: 100,
    );
    final rowHeight = m.rowHeights.last;
    // room for the 2 header rows plus 4 body rows; 1 header column plus 4
    final p = GridPagination.of(
      m,
      frozenRows: 2,
      frozenColumns: 1,
      width: 100 + 4 * 100 + 1,
      height: m.rowHeights[0] + m.rowHeights[1] + 4 * rowHeight + 1,
    );
    expect(p.rowBands, [(2, 6), (6, 10), (10, 13)]);
    expect(p.columnBands, [(1, 5), (5, 7)]);
    expect(p.pageCount, 6);
    expect(
      p.pages.first,
      const GridPage(rowStart: 2, rowEnd: 6, columnStart: 1, columnEnd: 5),
    );
    // down first, then across
    expect(p.pages[1].rowStart, 6);
    expect(p.pages[1].columnStart, 1);
    expect(p.pages[3].columnStart, 5);
    expect(p.pages[3].rowStart, 2);
  });

  test('a row taller than the page still gets a page; empty body', () async {
    final f = await facts(3);
    final grid = CubeGrid.of(
      Cube(
        facts: f,
        spec: CubeSpec(
          rows: CubeAxis.of([region]),
          aggregates: [Aggregate.sum(qty)],
        ),
      ).layout,
      strings: const TesseraStringsEn(),
    );
    final m = GridMetrics.of(
      grid,
      theme: const CubeExportTheme(),
      text: (c) => c.value?.toString() ?? '',
    );
    final tiny = GridPagination.of(
      m,
      frozenRows: 2,
      frozenColumns: 1,
      width: 1,
      height: 1,
    );
    expect(tiny.rowBands.length, grid.rowCount - 2);
    expect(tiny.columnBands.length, grid.columnCount - 1);
    final none = GridPagination.of(
      m,
      frozenRows: grid.rowCount,
      frozenColumns: grid.columnCount,
      width: 1000,
      height: 1000,
    );
    expect(none.pageCount, 1);
    expect(none.pages.single.rowStart, none.pages.single.rowEnd);
  });
}
