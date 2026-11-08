import 'package:test/test.dart';
import 'package:tessera/tessera.dart';
import 'package:tessera_html/tessera_html.dart';
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

/// The fragment parsed as XML (it is well-formed XHTML), rows as lists of
/// (tag, text, rowspan, colspan).
List<List<(String, String, int, int)>> table(String html) {
  final start = html.indexOf('<table');
  final end = html.indexOf('</table>') + '</table>'.length;
  final doc = XmlDocument.parse(html.substring(start, end));
  return [
    for (final tr in doc.findAllElements('tr'))
      [
        for (final cell in tr.childElements)
          (
            cell.name.local,
            cell.innerText,
            int.parse(cell.getAttribute('rowspan') ?? '1'),
            int.parse(cell.getAttribute('colspan') ?? '1'),
          ),
      ],
  ];
}

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

  test('a whole document with merged headers, classes and escaping', () {
    final html = const HtmlCubeExporter().export(
      cube().layout,
      title: 'Sales & <more>',
    );
    expect(html, startsWith('<!DOCTYPE html>\n<html lang="en">'));
    expect(html, contains('<title>Sales &amp; &lt;more&gt;</title>'));
    expect(html, contains('<style>'));
    expect(html, contains('table.tessera thead th { position: sticky;'));
    expect(html, endsWith('</body>\n</html>\n'));
    final rows = table(html);
    // header band: title over 2 columns, then A/B/… over 2 aggregates each
    expect(rows[0].first, ('th', 'category', 1, 2));
    expect(rows[0][2], ('th', 'A', 1, 2));
    expect(rows[1].take(3), [
      ('th', 'region', 1, 1),
      ('th', 'country', 1, 1),
      ('th', 'sum of qty', 1, 1),
    ]);
    // rows: ∅, Asia, Europe (label spans its 4 rows), ∅, Germany, Hungary, Σ
    expect(rows[2].first, ('th', '(empty)', 1, 2));
    expect(rows[4].first, ('th', 'Europe', 4, 1));
    expect(rows[4][1], ('th', '', 1, 1)); // the leg
    expect(rows[5].first, ('th', '(empty)', 1, 1)); // Europe's ∅ country
    expect(rows[6].first, ('th', 'Germany', 1, 1)); // no Europe cell here
    expect(rows[6][1], ('td', '', 1, 1)); // Germany × ∅ category: blank
    expect(rows[6][3], ('td', '1', 1, 1)); // Germany × A sum
    expect(rows[8].first, ('th', 'Total', 1, 2));
    expect(rows[8][rows[8].length - 2], ('td', '28.50', 1, 1)); // Σ sum
    expect(rows[8].last, ('td', '8', 1, 1)); // Σ count
    // labels are escaped (Iceland is under the collapsed ∅ region above)
    final byCountry = const HtmlCubeExporter().export(
      Cube(
        facts: f,
        spec: CubeSpec(rows: CubeAxis.of([country]), aggregates: [sumQty]),
      ).layout,
    );
    expect(byCountry, contains('Ice &lt;&quot;land&quot;&gt;'));
    expect(html, contains('class="tessera-data tessera-level-1 tessera-num"'));
    expect(html, contains('class="tessera-data tessera-summary tessera-num"'));
    expect(html, contains('class="tessera-header tessera-summary"'));
    expect(html, contains('class="tessera-leg tessera-row-level-0"'));
    expect(html, contains('scope="row"'));
    expect(html, contains('scope="col"'));
  });

  test('fragment, inline styles, no styles, theme and locale', () {
    final layout = Cube(
      facts: f,
      spec: CubeSpec(rows: CubeAxis.of([region]), aggregates: [sumQty]),
    ).layout;
    final fragment = HtmlCubeExporter(
      strings: TesseraStrings.forLanguage('hu')!,
      theme: CubeExportTheme.brand(
        primary: 0xFF1A73E8,
        fontFamily: 'Open Sans',
      ).copyWith(numberFormat: const NumberFormat(decimals: 1)),
      classPrefix: 'pv',
    ).export(layout, standalone: false, title: 'Riport');
    expect(fragment, startsWith('<style>'));
    expect(fragment, isNot(contains('<html')));
    expect(fragment, contains('table.pv th { background: #1a73e8;'));
    expect(fragment, contains('font-family: "Open Sans"'));
    expect(fragment, contains('color: #ffffff;'));
    expect(fragment, contains('<caption>Riport</caption>'));
    expect(fragment, contains('>Összesen<'));
    expect(fragment, contains('>28,5<')); // one decimal, Hungarian mark
    expect(fragment, contains('>11<')); // integers without decimals
    final inline = const HtmlCubeExporter(styling: HtmlStyling.inline)
        .export(layout, standalone: false);
    expect(inline, isNot(contains('<style>')));
    expect(inline, contains('style="border: 1px solid #bbbbbb;'));
    expect(inline, contains('background: #dddddd;')); // summary fill
    final bare = const HtmlCubeExporter(styling: HtmlStyling.none)
        .export(layout, standalone: false);
    expect(bare, startsWith('<table class="tessera">'));
    expect(bare, isNot(contains('style=')));
    expect(table(bare).last.first.$2, 'Total');
    // grouping with the locale's separator
    expect(const HtmlCubeExporter().formatNumber(1234567.891), '1,234,567.89');
    expect(
      HtmlCubeExporter(
        theme: const CubeExportTheme(
          numberFormat: NumberFormat(grouping: false),
        ),
      ).formatNumber(-1234.5),
      '-1234.50',
    );
  });

  test('a style: a class per look, after the level rules', () {
    // values by column depth only, and the first row level larger
    final style = JsonCubeStyle.fromJson({
      'format': 'tessera-style',
      'version': 1,
      'id': 'by-columns',
      'name': {'en': 'By columns'},
      'light': {
        'border': '#CCCCCC',
        'cell': {'fill': '#FFFFFF', 'text': '#000000'},
        'value': {
          'fill': ['#F0F0F0', '#E0E0E0'],
        },
        'rowLabel': {
          'size': [18, 12],
        },
      },
    });
    final theme = CubeExportTheme.fromStyle(
      style,
      coloring: DepthColoring.columns,
    );
    final html = HtmlCubeExporter(theme: theme).export(cube().layout);
    final grid = CubeGrid.of(cube().layout, strings: const TesseraStringsEn());
    final doc = XmlDocument.parse(
      html.substring(
        html.indexOf('<table'),
        html.indexOf('</table>') + '</table>'.length,
      ),
    );
    // every cell's look class carries its own fill and font
    final rules = {
      for (final m in RegExp(
        r'td\.tessera-look-(\d+) \{ background: (#[0-9a-f]{6}); '
        r'font-family: (\w+); font-size: ([\d.]+)pt;',
      ).allMatches(html))
        m.group(1)!: (m.group(2)!, double.parse(m.group(4)!)),
    };
    final cells = doc.findAllElements('td').toList();
    expect(cells, isNotEmpty);
    final data = [
      for (var r = 0; r < grid.rowCount; r++)
        for (var c = 0; c < grid.columnCount; c++)
          if (grid.cellAt(r, c) case final cell
              when cell.isOrigin && cell.kind == GridCellKind.data)
            cell,
    ];
    final tds = [
      for (final td in cells)
        if (td.getAttribute('class')!.contains('tessera-data')) td,
    ];
    expect(tds, hasLength(data.length));
    for (var i = 0; i < tds.length; i++) {
      final look = RegExp(r'tessera-look-(\d+)')
          .firstMatch(tds[i].getAttribute('class')!)!
          .group(1)!;
      final want = theme.fillOf(data[i]);
      expect(
        rules[look]!.$1,
        '#${(want & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
      );
    }
    // the look rules come after the level rules, so they win
    final css = html.substring(0, html.indexOf('</style>'));
    expect(
      css.indexOf('tessera-look-0'),
      greaterThan(css.lastIndexOf('tessera-level-')),
    );
    // a row label of the first level in 18 px, 15 pt
    expect(html, contains('font-size: 15pt;'));
  });

  test('aggregates outside the spec are rejected', () {
    expect(
      () => const HtmlCubeExporter().export(
        cube().layout,
        aggregates: [Aggregate.average(qty)],
      ),
      throwsArgumentError,
    );
  });
}
