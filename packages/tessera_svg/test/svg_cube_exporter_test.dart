import 'dart:io';

import 'package:test/test.dart';
import 'package:tessera/tessera.dart';
import 'package:tessera_svg/tessera_svg.dart';
import 'package:xml/xml.dart';

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
      [null, 'Ice <"land">', 'A', 7.5],
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

double attr(XmlElement e, String name) => double.parse(e.getAttribute(name)!);

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

  test('one rect per origin cell, merged cells span their columns', () {
    const exporter = SvgCubeExporter();
    final grid = CubeGrid.of(cube().layout, strings: const TesseraStringsEn());
    final svg = exporter.export(cube().layout, title: 'Sales & <more>');
    final doc = XmlDocument.parse(svg);
    final root = doc.rootElement;
    expect(root.name.local, 'svg');
    expect(
      root.getAttribute('viewBox'),
      '0 0 ${root.getAttribute('width')} '
      '${root.getAttribute('height')}',
    );
    expect(doc.findAllElements('title').single.innerText, 'Sales & <more>');
    final rects = doc
        .findAllElements('rect')
        .where((r) => r.parentElement!.name.local == 'g')
        .toList();
    var origins = 0;
    for (var r = 0; r < grid.rowCount; r++) {
      for (var c = 0; c < grid.columnCount; c++) {
        if (grid.cellAt(r, c).isOrigin) origins++;
      }
    }
    expect(rects.length, origins);
    final metrics = exporter.metricsOf(grid);
    expect(attr(root, 'width'), metrics.width);
    expect(attr(root, 'height'), metrics.height);
    // the column title spans both header columns
    final title = rects.first;
    expect(title.getAttribute('class'), 'tessera-title');
    expect(
      attr(title, 'width'),
      metrics.columnWidths[0] + metrics.columnWidths[1],
    );
    // Europe's label spans its 4 rows
    final europeRect = rects.firstWhere(
      (r) => attr(r, 'y') == metrics.y(2 + 2) && attr(r, 'x') == 0,
    );
    expect(europeRect.getAttribute('class'), 'tessera-header');
    expect(attr(europeRect, 'height'), metrics.spanHeight(2 + 2, 4));
    expect(
      rects.where((r) => r.getAttribute('class') == 'tessera-leg').length,
      1,
    );
    expect(
      rects.where((r) => r.getAttribute('class')!.contains('summary')),
      isNotEmpty,
    );
  });

  test('texts: escaped, numbers right-anchored and formatted, clipped', () {
    final svg = SvgCubeExporter(strings: TesseraStrings.forLanguage('hu')!)
        .export(cube().layout);
    final doc = XmlDocument.parse(svg);
    final texts = doc.findAllElements('text').toList();
    final byCountry = SvgCubeExporter().export(
      Cube(
        facts: f,
        spec: CubeSpec(rows: CubeAxis.of([country]), aggregates: [sumQty]),
      ).layout,
    );
    expect(byCountry, contains('Ice &lt;&quot;land&quot;&gt;</text>'));
    expect(
      XmlDocument.parse(byCountry)
          .findAllElements('text')
          .map((t) => t.innerText),
      contains('Ice <"land">'),
    );
    final value = texts.firstWhere((t) => t.innerText == '7,50');
    expect(value.getAttribute('text-anchor'), 'end');
    expect(value.getAttribute('clip-path'), startsWith('url(#c'));
    final label = texts.firstWhere((t) => t.innerText == 'Germany');
    expect(label.getAttribute('text-anchor'), isNull);
    // a merged label clips to its own area
    final europeText = texts.firstWhere((t) => t.innerText == 'Europe');
    final clip = europeText.getAttribute('clip-path')!;
    expect(clip, startsWith('url(#m'));
    final id = clip.substring('url(#'.length, clip.length - 1);
    expect(
      doc.findAllElements('clipPath').map((c) => c.getAttribute('id')),
      contains(id),
    );
    // legs and blanks carry no text
    expect(texts.where((t) => t.innerText.isEmpty), isEmpty);
    expect(svg, contains('>Összesen</text>'));
    expect(svg, startsWith('<?xml'));
  });

  test('theme fills and fonts, hue levels, measureText', () {
    final theme = CubeExportTheme.hueLevels(
      levels: const HueLevels(hue: 30),
      rowLevels: 2,
      columnLevels: 1,
    );
    final grid = CubeGrid.of(cube().layout, strings: const TesseraStringsEn());
    final svg = SvgCubeExporter(
      theme: theme,
      xmlDeclaration: false,
    ).export(cube().layout);
    expect(svg, isNot(startsWith('<?xml')));
    String rgb(int argb) =>
        '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    expect(svg, contains('fill="${rgb(theme.fillOf(grid.cellAt(2 + 4, 4)))}"'));
    expect(svg, contains('fill="${rgb(theme.rowHeaderFills[1])}"'));
    expect(svg, contains('fill="${rgb(theme.summaryFill)}"'));
    expect(svg, contains('font-weight="bold"')); // summary font
    // a measurer that makes every text 1000 px wide maxes the columns out
    final wide = SvgCubeExporter(
      measureText: (_, _) => 1000,
      maxColumnWidth: 150,
      maxHeaderColumnWidth: 120,
    );
    final m = wide.metricsOf(grid);
    expect(m.columnWidths[0], 120);
    expect(m.columnWidths[2], 150);
    expect(m.width, 2 * 120 + 8 * 150);
  });

  test(
    'renders with rsvg-convert',
    () async {
      final dir = Directory.systemTemp.createTempSync('tessera_svg');
      try {
        final file = File('${dir.path}/pivot.svg')
          ..writeAsStringSync(const SvgCubeExporter().export(cube().layout));
        final png = '${dir.path}/pivot.png';
        final result = await Process.run('rsvg-convert', [
          '-o',
          png,
          file.path,
        ]);
        expect(result.exitCode, 0, reason: '${result.stderr}');
        expect(File(png).lengthSync(), greaterThan(1000));
      } finally {
        dir.deleteSync(recursive: true);
      }
    },
    skip: Process.runSync('which', ['rsvg-convert']).exitCode != 0
        ? 'rsvg-convert not installed'
        : null,
  );
}
