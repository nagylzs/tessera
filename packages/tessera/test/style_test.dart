import 'dart:convert';

import 'package:test/test.dart';
import 'package:tessera/tessera.dart';

const region = ColumnDimension('region');
const country = ColumnDimension('country');
const year = ColumnDimension('year');
const qty = Measure('qty');

Future<FactTable> facts() async {
  final source = ListDataSource(
    columns: ['region', 'country', 'year', 'qty'],
    rows: const [
      ['Europe', 'Germany', '2024', 1],
      ['Europe', 'Hungary', '2025', 3],
      ['Asia', 'Japan', '2025', 5],
    ],
    declaredSchema: Schema([
      const ColumnSpec(name: 'region', type: ColumnType.text),
      const ColumnSpec(name: 'country', type: ColumnType.text),
      const ColumnSpec(name: 'year', type: ColumnType.text),
      const ColumnSpec(name: 'qty', type: ColumnType.number),
    ]),
  );
  return (await loadFacts(source)).facts;
}

/// A style using most of the format: roles, lists by depth, a dark variant.
Map<String, Object?> sample() => {
  '_comment': 'skipped',
  'format': 'tessera-style',
  'version': 1,
  'id': 'sample',
  'name': {'en': 'Sample', 'hu': 'Minta'},
  'metrics': {'rowHeight': 30, 'padding': 4},
  'light': {
    'border': '#CCCCCC',
    'selection': '#FF0000',
    'cell': {'fill': '#FFFFFF', 'text': '#111111', 'size': 12},
    'header': {
      'fill': ['#AA0000', '#BB0000'],
      'text': '#FFFFFF',
      'bold': [true, false],
    },
    'value': {
      'fill': ['#F0F0F0', '#E0E0E0', '#D0D0D0'],
    },
    'total': {'fill': '#999999', 'bold': true},
    'columnLabel': {
      'fill': '#0000AA',
      'family': 'serif',
      'size': [14, 12],
    },
    'title': {'italic': true},
  },
  'dark': {
    'border': '#333333',
    'cell': {'fill': '#000000', 'text': '#EEEEEE'},
    'value': {
      'fill': ['#101010', '#202020'],
    },
  },
};

void main() {
  final style = JsonCubeStyle.fromJson(sample());

  CellLook look(
    StyleCell cell, {
    bool dark = false,
    DepthColoring coloring = DepthColoring.both,
  }) => style.lookOf(cell, dark: dark, coloring: coloring);

  group('a JSON style', () {
    test('names, metrics and chrome', () {
      expect(style.id, 'sample');
      expect(style.name('hu'), 'Minta');
      expect(style.name('ja'), 'Sample'); // English where it has none
      expect(style.hasDark, isTrue);
      expect(style.metrics.rowHeight, 30);
      expect(style.metrics.headerRowHeight, 28); // the default
      expect(style.metrics.padding, 4);
      expect(style.chrome().border, 0xFFCCCCCC);
      expect(style.chrome().selection, 0xFFFF0000);
      // dark sets its border; the selection it takes from light
      expect(style.chrome(dark: true).border, 0xFF333333);
      expect(style.chrome(dark: true).selection, 0xFFFF0000);
      expect(style.chrome().sortKey, isNull);
    });

    test('values by depth, the last repeating', () {
      CellLook value(int row, int column) =>
          look(StyleCell(CellRole.value, rowLevel: row, columnLevel: column));
      expect(value(0, 0).fill, 0xFFF0F0F0);
      expect(value(1, 0).fill, 0xFFE0E0E0);
      expect(value(1, 1).fill, 0xFFD0D0D0);
      expect(value(3, 2).fill, 0xFFD0D0D0);
      // the rest from cell
      expect(value(0, 0).text, 0xFF111111);
      expect(value(0, 0).size, 12);
      expect(value(0, 0).bold, isFalse);
      expect(value(0, 0).family, isNull);
    });

    test('roles take from their parents', () {
      // rowLabel ← header ← cell
      final row0 = look(const StyleCell(CellRole.rowLabel, rowLevel: 0));
      final row1 = look(const StyleCell(CellRole.rowLabel, rowLevel: 1));
      expect(row0.fill, 0xFFAA0000);
      expect(row1.fill, 0xFFBB0000);
      expect(row0.text, 0xFFFFFFFF);
      expect(row0.bold, isTrue);
      expect(row1.bold, isFalse);
      expect(row0.size, 12);
      // valueName ← columnLabel ← header
      final name1 = look(const StyleCell(CellRole.valueName, columnLevel: 1));
      expect(name1.fill, 0xFF0000AA);
      expect(name1.family, StyleFamily.serif);
      expect(name1.size, 12);
      expect(
        look(const StyleCell(CellRole.valueName, columnLevel: 0)).size,
        14,
      );
      expect(name1.bold, isFalse); // header's, at depth 1
      // totalLabel ← total ← cell
      final totalLabel = look(const StyleCell(CellRole.totalLabel));
      expect(totalLabel.fill, 0xFF999999);
      expect(totalLabel.bold, isTrue);
      expect(totalLabel.text, 0xFF111111);
      // title ← header
      final title = look(const StyleCell(CellRole.title, rowLevel: 1));
      expect(title.italic, isTrue);
      expect(title.fill, 0xFFBB0000);
      // corner ← header
      expect(look(const StyleCell(CellRole.corner)).fill, 0xFFAA0000);
    });

    test('dark takes what it does not set from light', () {
      final value = look(
        const StyleCell(CellRole.value, rowLevel: 1, columnLevel: 1),
        dark: true,
      );
      expect(value.fill, 0xFF202020);
      expect(value.text, 0xFFEEEEEE); // dark's cell
      expect(value.size, 12); // light's cell
      // colours along dark's own chain first: a header falls to dark's
      // cell, which keeps its fill and text from one variant
      final header = look(
        const StyleCell(CellRole.rowLabel, rowLevel: 0),
        dark: true,
      );
      expect(header.fill, 0xFF000000);
      expect(header.text, 0xFFEEEEEE);
      // what dark sets nowhere along it comes from light
      expect(header.bold, isTrue);
      // without a dark variant, light serves
      final light = JsonCubeStyle.fromJson(sample()..remove('dark'));
      expect(light.hasDark, isFalse);
      expect(
        light.lookOf(const StyleCell(CellRole.value), dark: true).fill,
        0xFFF0F0F0,
      );
    });

    test('the depth coloring picks the colours, not the fonts', () {
      const deep = StyleCell(CellRole.value, rowLevel: 1, columnLevel: 1);
      expect(look(deep, coloring: DepthColoring.off).fill, 0xFFF0F0F0);
      expect(look(deep, coloring: DepthColoring.rows).fill, 0xFFE0E0E0);
      expect(look(deep, coloring: DepthColoring.columns).fill, 0xFFE0E0E0);
      expect(look(deep, coloring: DepthColoring.both).fill, 0xFFD0D0D0);
      const columnOnly = StyleCell(CellRole.value, rowLevel: 0, columnLevel: 1);
      expect(look(columnOnly, coloring: DepthColoring.rows).fill, 0xFFF0F0F0);
      // headers by their own axis
      const row1 = StyleCell(CellRole.rowLabel, rowLevel: 1);
      expect(look(row1, coloring: DepthColoring.columns).fill, 0xFFAA0000);
      expect(look(row1, coloring: DepthColoring.rows).fill, 0xFFBB0000);
      // the font keeps the cell's own depth
      expect(look(row1, coloring: DepthColoring.off).bold, isFalse);
      expect(
        look(
          const StyleCell(CellRole.rowLabel, rowLevel: 0),
          coloring: DepthColoring.off,
        ).bold,
        isTrue,
      );
    });

    test('round-trips through its JSON', () {
      final again = JsonCubeStyle.parse(jsonEncode(style.toJson()));
      expect(again.id, style.id);
      expect(
        again.lookOf(const StyleCell(CellRole.valueName, columnLevel: 0)),
        style.lookOf(const StyleCell(CellRole.valueName, columnLevel: 0)),
      );
    });
  });

  group('a JSON style that is wrong says where', () {
    void fails(void Function(Map<String, Object?> json) change, String path) {
      final json = jsonDecode(jsonEncode(sample())) as Map<String, Object?>;
      change(json);
      expect(
        () => JsonCubeStyle.fromJson(json),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            startsWith(path),
          ),
        ),
      );
    }

    Map<String, Object?> light(Map<String, Object?> json) =>
        json['light']! as Map<String, Object?>;
    Map<String, Object?> role(Map<String, Object?> json, String name) =>
        light(json)[name]! as Map<String, Object?>;

    test('in the header', () {
      fails((j) => j['format'] = 'other', r'$.format');
      fails((j) => j['version'] = 2, r'$.version');
      fails((j) => j.remove('id'), r'$.id');
      fails((j) => j['name'] = {'hu': 'Minta'}, r'$.name');
      fails((j) => j['colour'] = 1, r'$.colour');
      fails((j) => j['metrics'] = {'rowHeight': -1}, r'$.metrics.rowHeight');
    });

    test('in a variant', () {
      fails((j) => j.remove('light'), r'$.light');
      fails((j) => light(j).remove('border'), r'$.light.border');
      fails((j) => role(j, 'cell').remove('text'), r'$.light.cell');
      fails((j) => light(j)['values'] = {}, r'$.light.values');
      fails((j) => role(j, 'value')['fill'] = [], r'$.light.value.fill');
      fails(
        (j) => role(j, 'value')['fill'] = ['#F0F0F0', 'red'],
        r'$.light.value.fill[1]',
      );
      fails((j) => role(j, 'value')['fill'] = '#FFF', r'$.light.value.fill');
      fails((j) => role(j, 'header')['bold'] = 'yes', r'$.light.header.bold');
      fails(
        (j) => role(j, 'cell')['family'] = 'cursive',
        r'$.light.cell.family',
      );
      fails((j) => role(j, 'cell')['size'] = 0, r'$.light.cell.size');
      fails(
        (j) =>
            (j['dark']! as Map<String, Object?>)['cell'] = {'fill': '#000000'},
        r'$.dark.cell',
      );
    });

    test('not JSON at all', () {
      expect(() => JsonCubeStyle.parse('{'), throwsFormatException);
      expect(() => JsonCubeStyle.parse('[]'), throwsFormatException);
    });

    test('colours: six digits, or eight with the alpha first', () {
      final json = sample();
      light(json)['sortKey'] = '#40FF0000';
      expect(JsonCubeStyle.fromJson(json).chrome().sortKey, 0x40FF0000);
    });
  });

  group('exports in a style', () {
    late FactTable f;
    setUpAll(() async => f = await facts());

    CubeGrid grid() {
      final cube = Cube(
        facts: f,
        spec: CubeSpec(
          rows: CubeAxis.of([region, country]),
          columns: CubeAxis.of([year]),
          aggregates: [Aggregate.sum(qty)],
        ),
      );
      final layout = cube.layout;
      return CubeGrid.of(layout, strings: const TesseraStringsEn());
    }

    test('every grid cell is a style cell', () {
      final g = grid();
      final roles = <CellRole>{};
      for (var r = 0; r < g.rowCount; r++) {
        for (var c = 0; c < g.columnCount; c++) {
          final cell = g.cellAt(r, c);
          final s = StyleCell.ofGrid(cell);
          roles.add(s.role);
          if (cell.kind == GridCellKind.data && !cell.isSummary) {
            expect(s.rowLevel, cell.rowLevel);
            expect(s.columnLevel, cell.columnLevel);
          }
          if (cell.kind == GridCellKind.rowTitle) {
            expect(s.onRowAxis, isTrue);
          }
          if (cell.kind == GridCellKind.columnTitle) {
            expect(s.onColumnAxis, isTrue);
          }
        }
      }
      expect(
        roles,
        containsAll([
          CellRole.value,
          CellRole.total,
          CellRole.rowLabel,
          CellRole.columnLabel,
          CellRole.totalLabel,
          CellRole.title,
          CellRole.valueName,
        ]),
      );
    });

    test('fills and fonts per cell, light, sized for documents', () {
      final theme = CubeExportTheme.fromStyle(
        style,
        families: const ExportFamilies(serif: 'Noto Serif'),
      );
      final g = grid();
      for (var r = 0; r < g.rowCount; r++) {
        for (var c = 0; c < g.columnCount; c++) {
          final cell = g.cellAt(r, c);
          final want = style.lookOf(StyleCell.ofGrid(cell));
          expect(theme.fillOf(cell), want.fill, reason: '$cell');
          final font = theme.fontOf(cell);
          expect(font.color, want.text);
          expect(font.size, closeTo(want.size * 5 / 6, 1e-9));
          expect(font.bold, want.bold);
          expect(
            font.family,
            want.family == StyleFamily.serif ? 'Noto Serif' : 'Arial',
          );
        }
      }
      expect(theme.borderColor, 0xFFCCCCCC);
      // the plain fields hold the first levels
      expect(theme.levelFills.take(3), [0xFFF0F0F0, 0xFFE0E0E0, 0xFFD0D0D0]);
      expect(theme.summaryFill, 0xFF999999);
    });

    test('the coloring reaches the cells', () {
      final flat = CubeExportTheme.fromStyle(
        style,
        coloring: DepthColoring.off,
      );
      final g = grid();
      for (var r = 0; r < g.rowCount; r++) {
        for (var c = 0; c < g.columnCount; c++) {
          final cell = g.cellAt(r, c);
          if (cell.kind == GridCellKind.data && !cell.isSummary) {
            expect(flat.fillOf(cell), 0xFFF0F0F0);
          }
        }
      }
    });

    test('a new number format keeps the style; other changes do not', () {
      final theme = CubeExportTheme.fromStyle(style);
      final g = grid();
      final valueCell = [
        for (var r = 0; r < g.rowCount; r++)
          for (var c = 0; c < g.columnCount; c++)
            if (g.cellAt(r, c) case final cell
                when cell.kind == GridCellKind.data && !cell.isSummary)
              cell,
      ].first;
      final decimals = theme.copyWith(
        numberFormat: const NumberFormat(decimals: 0),
      );
      expect(decimals.numberFormat.decimals, 0);
      expect(decimals.fillOf(valueCell), theme.fillOf(valueCell));
      final plain = theme.copyWith(levelFills: const [0xFF123456]);
      expect(plain.fillOf(valueCell), 0xFF123456);
    });

    test('rows as high as their largest font', () {
      final big = sample();
      ((big['light']! as Map)['header'] as Map)['size'] = [24, 12];
      final theme = CubeExportTheme.fromStyle(JsonCubeStyle.fromJson(big));
      final plainTheme = CubeExportTheme.fromStyle(style);
      final g = grid();
      String text(GridCell c) => c.value?.toString() ?? '';
      final tall = GridMetrics.of(g, theme: theme, text: text);
      final plain = GridMetrics.of(g, theme: plainTheme, text: text);
      // the first row group's labels are 24: its rows grow, no others
      var grew = 0;
      for (var r = 0; r < g.rowCount; r++) {
        if (tall.rowHeights[r] > plain.rowHeights[r]) grew++;
      }
      expect(grew, greaterThan(0));
      expect(grew, lessThan(g.rowCount));
    });
  });
}
