import 'package:test/test.dart';
import 'package:tessera/tessera.dart';

const region = ColumnDimension('region');
const country = ColumnDimension('country');
const category = ColumnDimension('category');
const qty = Measure('qty');
final sumQty = Aggregate.sum(qty);

Future<FactTable> facts() async {
  final source = ListDataSource(
    columns: ['region', 'country', 'category', 'qty'],
    rows: const [
      ['Europe', 'Germany', 'A', 1],
      ['Europe', 'Germany', 'B', 2],
      ['Europe', 'Hungary', 'A', 3],
      ['Europe', null, 'A', 4],
      ['Asia', 'Japan', 'B', 5],
      ['Asia', 'Japan', null, 6],
      [null, 'Ice, "land"', 'A', 7.5],
      [null, null, null, null],
    ],
    declaredSchema: Schema([
      const ColumnSpec(name: 'region', type: ColumnType.text),
      const ColumnSpec(name: 'country', type: ColumnType.text),
      const ColumnSpec(name: 'category', type: ColumnType.text),
      const ColumnSpec(name: 'qty', type: ColumnType.number),
    ]),
  );
  return (await loadFacts(source)).facts;
}

final europe = DimensionPath([const DimensionValue(region, 'Europe')]);

void main() {
  late FactTable f;
  setUpAll(() async => f = await facts());

  Cube cube() => Cube(
    facts: f,
    spec: CubeSpec(
      rows: CubeAxis.of([region, country]),
      columns: CubeAxis.of([category]),
      aggregates: [sumQty, Aggregate.count],
    ),
  ).toggleRow(europe);

  group('CubeGrid', () {
    test('mirrors the view: headers, merges, levels', () {
      final g = CubeGrid.of(cube().layout, strings: const TesseraStringsEn());
      // 2 header rows, 2 header columns, 4 column entries × 2 aggregates
      expect(g.headerRows, 2);
      expect(g.headerColumns, 2);
      expect(g.columnsPerEntry, 2);
      expect(g.rowCount, 2 + 7);
      expect(g.columnCount, 2 + 8);
      // corner: the column title spans both header columns
      final title = g.cellAt(0, 0);
      expect(title.kind, GridCellKind.columnTitle);
      expect(title.value, 'category');
      expect(title.columnSpan, 2);
      expect(g.cellAt(0, 1).isOrigin, isFalse);
      expect(g.cellAt(0, 1).value, 'category'); // covered cells repeat it
      expect(g.cellAt(1, 0).value, 'region');
      expect(g.cellAt(1, 1).value, 'country');
      // a column entry spans its two aggregates on the label row
      final a = g.cellAt(0, 4);
      expect(a.kind, GridCellKind.columnLabel);
      expect(a.value, 'A');
      expect(a.columnSpan, 2);
      expect(g.cellAt(1, 4).value, 'sum of qty');
      expect(g.cellAt(1, 5).value, 'count');
      expect(g.cellAt(0, 8).isSummary, isTrue);
      // rows: ∅, Asia, Europe, ∅, Germany, Hungary, Σ
      final eu = g.cellAt(2 + 2, 0);
      expect(eu.value, 'Europe');
      expect(eu.rowSpan, 4);
      expect(eu.path, europe);
      final leg = g.cellAt(2 + 2, 1);
      expect(leg.isLeg, isTrue);
      expect(leg.value, isNull);
      expect(g.cellAt(2 + 4, 1).value, 'Germany');
      expect(g.cellAt(2 + 6, 0).isSummary, isTrue);
      expect(g.cellAt(2 + 6, 0).columnSpan, 2); // Σ spans both levels
      // data: Germany × A = 1 at level 1, Europe × Σ summary
      final d = g.cellAt(2 + 4, 4);
      expect(d.kind, GridCellKind.data);
      expect(d.value, 1);
      expect(d.level, 1);
      expect(g.cellAt(2 + 4, 5).value, 1); // count
      expect(g.cellAt(2 + 2, 8).isSummary, isTrue);
      expect(g.cellAt(2 + 2, 8).value, 10);
      // an aggregate outside the spec is rejected
      expect(
        () => CubeGrid.of(
          cube().layout,
          strings: const TesseraStringsEn(),
          aggregates: [Aggregate.average(qty)],
        ),
        throwsArgumentError,
      );
    });
  });

  group('CubeExportTheme', () {
    test('brand, gradient, mix, level fills, number format', () {
      final theme = CubeExportTheme.brand(
        primary: 0xFF1A73E8,
        fontFamily: 'Calibri',
        levels: 3,
      );
      expect(theme.headerFill, 0xFF1A73E8);
      expect(theme.headerFont.color, 0xFFFFFFFF);
      expect(theme.headerFont.family, 'Calibri');
      expect(theme.levelFills.length, 3);
      expect(theme.levelFills.first, 0xFFFFFFFF);
      expect(theme.levelFill(0), 0xFFFFFFFF);
      expect(theme.levelFill(99), theme.levelFills.last);
      expect(theme.levelFill(1, summary: true), theme.summaryFill);
      expect(const CubeExportTheme(levelFills: []).levelFill(0), 0xFFFFFFFF);
      expect(CubeExportTheme.mix(0xFF000000, 0xFFFFFFFF, 0.5), 0xFF808080);
      expect(CubeExportTheme.gradient(0xFF000000, 0xFF0000FF, 3), [
        0xFF000000,
        0xFF000080,
        0xFF0000FF,
      ]);
      expect(CubeExportTheme.gradient(0xFF123456, 0xFF000000, 1), [0xFF123456]);
      expect(const NumberFormat(), const NumberFormat(decimals: 2));
      expect(
        theme
            .copyWith(numberFormat: const NumberFormat(decimals: 0))
            .numberFormat
            .decimals,
        0,
      );
      expect(
        const ExportFont().copyWith(bold: true),
        const ExportFont(bold: true),
      );
    });
  });

  group('CsvCubeExporter', () {
    test('writes the grid with labels at the origin', () {
      final csv = const CsvCubeExporter(
        options: CsvExportOptions(lineEnding: '\n'),
      ).export(cube().layout, aggregates: [sumQty]);
      expect(csv.split('\n'), [
        'category,,(empty),A,B,Total',
        'region,country,sum of qty,sum of qty,sum of qty,sum of qty',
        '(empty),,,7.5,,7.5',
        'Asia,,6,,5,11',
        'Europe,,,8,2,10',
        ',(empty),,4,,4',
        ',Germany,,1,2,3',
        ',Hungary,,3,,3',
        'Total,,6,15.5,7,28.5',
        '',
      ]);
    });

    test('repeats group labels, quotes, separators, localized', () {
      final csv =
          CsvCubeExporter(
            strings: TesseraStrings.forLanguage('hu')!,
            options: const CsvExportOptions(
              delimiter: ';',
              decimalSeparator: ',',
              lineEnding: '\n',
              groupLabels: CsvGroupLabels.repeat,
              byteOrderMark: true,
            ),
          ).export(
            Cube(
              facts: f,
              spec: CubeSpec(
                rows: CubeAxis.of([region, country]),
                aggregates: [sumQty],
              ),
            ).expandRowsToDepth(2).layout,
          );
      final lines = csv.split('\n');
      expect(lines.first, '﻿;;Összesen'); // no column dims: blank corner
      expect(lines[1], 'region;country;qty összege');
      // every row carries its region; the country with , and " is quoted
      expect(lines[2], '(üres);;7,5'); // the group's own row: leg blank
      expect(lines[3], '(üres);(üres);'); // null value → empty field
      expect(lines[4], '(üres);"Ice, ""land""";7,5');
      expect(lines[5], 'Asia;;11');
      expect(lines[6], 'Asia;Japan;11');
      expect(lines[7], 'Europe;;10');
      expect(lines.last, '');
      // origin mode leaves the group column blank on child rows
      final plain =
          const CsvCubeExporter(options: CsvExportOptions(lineEnding: '\n'))
              .export(
                Cube(
                  facts: f,
                  spec: CubeSpec(
                    rows: CubeAxis.of([region, country]),
                    aggregates: [sumQty],
                  ),
                ).expandRowsToDepth(2).layout,
              );
      expect(plain.split('\n')[6], ',Japan,11');
      expect(CsvExportOptions.europeanExcel.delimiter, ';');
    });

    test('writeTo streams into a sink', () {
      final buffer = StringBuffer();
      const CsvCubeExporter().writeTo(buffer, cube().layout);
      expect(buffer.toString(), startsWith('category,,'));
      expect(buffer.toString(), endsWith('\r\n'));
      expect(CsvCubeExporter.formatNumber(10.0, '.'), '10');
      expect(CsvCubeExporter.formatNumber(2.5, ','), '2,5');
      expect(CsvCubeExporter.formatNumber(3, '.'), '3');
      expect(CsvCubeExporter.formatNumber(0.1 + 0.2, '.'), '0.3');
      expect(
        CsvCubeExporter.formatNumber(135034.64000000004, ','),
        '135034,64',
      );
      expect(CsvCubeExporter.formatNumber(1e21, '.'), '1e+21');
      expect(CsvCubeExporter.formatNumber(double.nan, '.'), 'NaN');
    });
  });
}
