import 'package:test/test.dart';
import 'package:tessera/tessera.dart';

const region = ColumnDimension('region');
const country = ColumnDimension('country');
const qty = Measure('qty');

Future<FactTable> facts() async {
  final source = ListDataSource(
    columns: ['region', 'country', 'qty'],
    rows: const [
      ['Europe', 'Germany', 1],
      ['Europe', 'Hungary', 3],
      ['Asia', 'Japan', 5],
    ],
    declaredSchema: Schema([
      const ColumnSpec(name: 'region', type: ColumnType.text),
      const ColumnSpec(name: 'country', type: ColumnType.text),
      const ColumnSpec(name: 'qty', type: ColumnType.number),
    ]),
  );
  return (await loadFacts(source)).facts;
}

void main() {
  late FactTable f;
  setUpAll(() async => f = await facts());

  CubeGrid grid({String label = 'country'}) => CubeGrid.of(
    Cube(
      facts: f,
      spec: CubeSpec(
        rows: CubeAxis.of([region]),
        columns: CubeAxis.of([ColumnDimension('country', label: label)]),
        aggregates: [Aggregate.sum(qty)],
      ),
    ).layout,
    strings: const TesseraStringsEn(),
  );

  String text(GridCell c) => c.value?.toString() ?? '';

  test('estimateWidth grows with text and font, bold a little more', () {
    const font = ExportFont(size: 10);
    expect(GridMetrics.estimateWidth('', font), 0);
    final a = GridMetrics.estimateWidth('abc', font);
    expect(GridMetrics.estimateWidth('abcdef', font), greaterThan(a));
    expect(
      GridMetrics.estimateWidth('abc', const ExportFont(size: 20)),
      closeTo(2 * a, 0.001),
    );
    expect(
      GridMetrics.estimateWidth('abc', const ExportFont(size: 10, bold: true)),
      greaterThan(a),
    );
    expect(GridMetrics.fontPixels(12), closeTo(16, 0.001));
  });

  test('widths clamp per column kind, offsets accumulate, rows from fonts', () {
    final g = grid();
    final m = GridMetrics.of(
      g,
      theme: const CubeExportTheme(),
      text: text,
      minColumnWidth: 50,
      maxColumnWidth: 80,
      minHeaderColumnWidth: 100,
      maxHeaderColumnWidth: 120,
      lineHeight: 2,
    );
    expect(m.columnWidths.length, g.columnCount);
    expect(m.rowHeights.length, g.rowCount);
    expect(m.columnWidths[0], inInclusiveRange(100, 120));
    for (var c = 1; c < g.columnCount; c++) {
      expect(m.columnWidths[c], inInclusiveRange(50, 80));
    }
    expect(m.columnOffsets.first, 0);
    expect(m.columnOffsets.length, g.columnCount + 1);
    expect(m.width, m.columnWidths.fold(0.0, (a, b) => a + b));
    expect(m.height, m.rowHeights.fold(0.0, (a, b) => a + b));
    expect(m.x(2), m.columnWidths[0] + m.columnWidths[1]);
    expect(m.spanWidth(1, 2), m.columnWidths[1] + m.columnWidths[2]);
    expect(m.spanHeight(0, g.rowCount), m.height);
    // 10 pt font → 13.33 px × 2, rounded up
    expect(m.rowHeights.first, 27);
  });

  test('a merged cell widens the columns it spans', () {
    // two row levels: the column title merges over both header columns
    final g = CubeGrid.of(
      Cube(
        facts: f,
        spec: CubeSpec(
          rows: CubeAxis.of([region, country]),
          columns: CubeAxis.of([const ColumnDimension('qty', label: 'wide')]),
          aggregates: [Aggregate.sum(qty)],
        ),
      ).layout,
      strings: const TesseraStringsEn(),
    );
    expect(g.cellAt(0, 0).columnSpan, 2);
    final m = GridMetrics.of(
      g,
      theme: const CubeExportTheme(),
      text: text,
      measure: (t, _) => t == 'wide' ? 500 : 10,
      minHeaderColumnWidth: 100,
      maxHeaderColumnWidth: 1000,
      padding: 5,
    );
    // 510 needed over two 100 px columns: the shortfall is shared
    expect(m.columnWidths[0], 255);
    expect(m.columnWidths[1], 255);
    expect(m.columnWidths[2], 60);
    // capped at the span's maximum
    final capped = GridMetrics.of(
      g,
      theme: const CubeExportTheme(),
      text: text,
      measure: (t, _) => t == 'wide' ? 5000 : 10,
      minHeaderColumnWidth: 100,
      maxHeaderColumnWidth: 120,
    );
    expect(capped.columnWidths[0], 120);
    expect(capped.columnWidths[1], 120);
  });
}
