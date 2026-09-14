import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:tessera/tessera.dart';

const snapshot = TesseraSnapshot();

Future<FactTable> sales() async {
  final bytes = File('test/data/sales.csv').readAsBytesSync();
  return (await loadFacts(CsvDataSource.fromData(bytes))).facts;
}

Future<FactTable> table(
  List<String> columns,
  List<List<Object?>> rows,
  Map<String, ColumnType> types,
) async {
  final source = ListDataSource(
    columns: columns,
    rows: rows,
    declaredSchema: Schema([
      for (final e in types.entries) ColumnSpec(name: e.key, type: e.value),
    ]),
  );
  return (await loadFacts(source)).facts;
}

void expectSameFacts(FactTable a, FactTable b) {
  expect(b.rowCount, a.rowCount);
  expect(
    b.columns.map((c) => (c.name, c.label, c.type)),
    a.columns.map((c) => (c.name, c.label, c.type)),
  );
  for (final c in a.columns) {
    for (var r = 0; r < a.rowCount; r++) {
      expect(
        b.valueAt(r, c.name),
        a.valueAt(r, c.name),
        reason: '${c.name}[$r]',
      );
    }
    expect(b.column(c.name).nullCount, a.column(c.name).nullCount);
    expect(b.column(c.name).distinctCount, a.column(c.name).distinctCount);
  }
}

Map<String, Object?> headerOf(Uint8List bytes) {
  final len = ByteData.sublistView(bytes).getUint32(8, Endian.little);
  return jsonDecode(utf8.decode(bytes.sublist(12, 12 + len)))
      as Map<String, Object?>;
}

void main() {
  test('sales.csv round-trips with its configuration', () async {
    final f = await sales();
    final spec = CubeSpec(
      rows: CubeAxis.of([
        const ColumnDimension('region'),
        const ColumnDimension('country'),
      ]),
      columns: CubeAxis.of([const DatePartDimension('date', DatePart.year)]),
      aggregates: [Aggregate.sum(const Measure('total')), Aggregate.count],
      filter: ExpressionFilter('total > 100'),
    );
    final cube = Cube(facts: f, spec: spec).expandRowsToDepth(2);
    final bytes = snapshot.encode(f, config: CubeConfig.of(cube));
    expect(String.fromCharCodes(bytes, 0, 4), 'TSNP');
    final back = snapshot.decode(bytes);
    expectSameFacts(f, back.facts);
    expect(
      back.facts.schema.columns.map((c) => c.name),
      f.schema.columns.map((c) => c.name),
    );
    final restored = back.config!.toCube(back.facts);
    final a = cube.layout, b = restored.layout;
    expect(
      b.rows.entries.map((e) => e.path),
      a.rows.entries.map((e) => e.path),
    );
    for (var r = 0; r < a.rows.length; r++) {
      expect(b.cellAt(r, 0).aggregates, a.cellAt(r, 0).aggregates);
    }
    // sections are aligned and narrow
    final header = headerOf(bytes);
    for (final c in header['columns'] as List) {
      final col = c as Map;
      for (final key in ['data', 'codes', 'dictionary']) {
        final s = col[key];
        if (s is Map) {
          expect((s['offset'] as int) % 8, 0, reason: '${col['name']} $key');
        }
      }
    }
    final region = (header['columns'] as List).firstWhere(
      (c) => c['name'] == 'region',
    ) as Map;
    expect((region['codes'] as Map)['encoding'], 'i8');
    expect(
      (region['dictionary'] as Map)['count'],
      f.column('region').distinctCount,
    );
    // without config
    expect(snapshot.decode(snapshot.encode(f)).config, isNull);
    // considerably smaller than the CSV
    expect(bytes.length, lessThan(File('test/data/sales.csv').lengthSync()));
  });

  test('every type and null, every code width', () async {
    final wide = [for (var i = 0; i < 40000; i++) 'v$i'];
    final f = await table(
      ['t8', 't16', 't32', 'i', 'n', 'b', 'd', 'dt'],
      [
        for (var i = 0; i < 40000; i++)
          [
            i % 7 == 0 ? null : 'a${i % 100}',
            i % 11 == 0 ? null : 'b${i % 1000}',
            i % 13 == 0 ? null : wide[i],
            i % 3 == 0 ? null : i,
            i % 5 == 0 ? null : i / 4,
            i % 2 == 0 ? null : i % 4 == 1,
            i % 17 == 0 ? null : '2024-01-${1 + i % 28}',
            i % 19 == 0 ? null : '2024-01-01T${i % 24}:30:00',
          ],
      ],
      {
        't8': ColumnType.text,
        't16': ColumnType.text,
        't32': ColumnType.text,
        'i': ColumnType.integer,
        'n': ColumnType.number,
        'b': ColumnType.boolean,
        'd': ColumnType.date,
        'dt': ColumnType.dateTime,
      },
    );
    final bytes = snapshot.encode(f);
    final header = headerOf(bytes);
    String enc(String name) =>
        ((header['columns'] as List).firstWhere(
                  (c) => c['name'] == name,
                )['codes']
                as Map)['encoding']
            as String;
    expect(enc('t8'), 'i8');
    expect(enc('t16'), 'i16');
    expect(enc('t32'), 'i32');
    expectSameFacts(f, snapshot.decode(bytes).facts);
    // an unaligned buffer (as a slice of a larger one) decodes too
    final shifted = Uint8List(bytes.length + 3)
      ..setRange(3, bytes.length + 3, bytes);
    expectSameFacts(
      f,
      snapshot.decode(Uint8List.sublistView(shifted, 3)).facts,
    );
  });

  test('an empty table and unicode text', () async {
    final empty = await table(
      ['a', 'n'],
      [],
      {'a': ColumnType.text, 'n': ColumnType.number},
    );
    final back = snapshot.decode(snapshot.encode(empty)).facts;
    expect(back.rowCount, 0);
    expect(back.columns.map((c) => c.name), ['a', 'n']);
    final uni = await table(
      ['a'],
      [
        ['árvíztűrő'],
        ['日本'],
        ['🙂'],
        [''],
      ],
      {'a': ColumnType.text},
    );
    expectSameFacts(uni, snapshot.decode(snapshot.encode(uni)).facts);
  });

  test('a snapshot written by hand from the spec decodes', () {
    // Two rows: region (text, i8), qty (integer, f64), ok (boolean, u8).
    final header = utf8.encode(
      jsonEncode({
        'rows': 2,
        'schema': {
          'columns': [
            {'name': 'region', 'type': 'text', 'label': 'Region'},
            {'name': 'qty', 'type': 'integer'},
            {'name': 'ok', 'type': 'boolean'},
          ],
        },
        'columns': [
          {
            'name': 'region',
            'label': 'Region',
            'type': 'text',
            'dictionary': {'count': 2, 'offset': 0, 'length': 8 + 6 + 4},
            'codes': {'encoding': 'i8', 'offset': 24, 'length': 2},
          },
          {
            'name': 'qty',
            'type': 'integer',
            'data': {'encoding': 'f64', 'offset': 32, 'length': 16},
          },
          {
            'name': 'ok',
            'type': 'boolean',
            'data': {'encoding': 'u8', 'offset': 48, 'length': 2},
          },
        ],
        'extra': 'ignored',
      }),
    );
    final dataStart = (12 + header.length + 7) ~/ 8 * 8;
    final bytes = Uint8List(dataStart + 56);
    final view = ByteData.sublistView(bytes);
    bytes.setRange(0, 4, 'TSNP'.codeUnits);
    view.setUint32(4, 1, Endian.little);
    view.setUint32(8, header.length, Endian.little);
    bytes.setRange(12, 12 + header.length, header);
    var p = dataStart;
    // dictionary: "Europe", "Asia"
    view.setUint32(p, 6, Endian.little);
    view.setUint32(p + 4, 4, Endian.little);
    bytes.setRange(p + 8, p + 14, utf8.encode('Europe'));
    bytes.setRange(p + 14, p + 18, utf8.encode('Asia'));
    // codes at +24: row 0 = Asia, row 1 = null
    p = dataStart + 24;
    view.setInt8(p, 1);
    view.setInt8(p + 1, -1);
    // qty at +32
    p = dataStart + 32;
    view.setFloat64(p, 42, Endian.little);
    view.setFloat64(p + 8, double.nan, Endian.little);
    // ok at +48
    p = dataStart + 48;
    bytes[p] = 1;
    bytes[p + 1] = 2;
    final f = snapshot.decode(bytes).facts;
    expect(f.rowCount, 2);
    expect(f.column('region').label, 'Region');
    expect(f.valueAt(0, 'region'), 'Asia');
    expect(f.valueAt(1, 'region'), isNull);
    expect(f.valueAt(0, 'qty'), 42);
    expect(f.valueAt(1, 'qty'), isNull);
    expect(f.valueAt(0, 'ok'), true);
    expect(f.valueAt(1, 'ok'), isNull);
    expect(f.column('qty').type, ColumnType.integer);
    // and survives the encoder's own round trip
    expectSameFacts(f, snapshot.decode(snapshot.encode(f)).facts);
  });

  test('malformed snapshots are rejected', () async {
    final f = await table(
      ['a', 'n', 'b'],
      [
        ['x', 1, true],
        [null, null, null],
      ],
      {'a': ColumnType.text, 'n': ColumnType.number, 'b': ColumnType.boolean},
    );
    final good = snapshot.encode(f);
    expect(snapshot.decode(good).facts.rowCount, 2);

    Uint8List patched(
      void Function(Map<String, Object?> header, Uint8List data) edit,
    ) {
      final header = headerOf(good);
      final headerLen = ByteData.sublistView(good).getUint32(8, Endian.little);
      final dataStart = (12 + headerLen + 7) ~/ 8 * 8;
      final data = Uint8List.fromList(good.sublist(dataStart));
      edit(header, data);
      final h = utf8.encode(jsonEncode(header));
      final ds = (12 + h.length + 7) ~/ 8 * 8;
      final out = Uint8List(ds + data.length);
      final view = ByteData.sublistView(out);
      out.setRange(0, 4, 'TSNP'.codeUnits);
      view.setUint32(4, 1, Endian.little);
      view.setUint32(8, h.length, Endian.little);
      out.setRange(12, 12 + h.length, h);
      out.setRange(ds, ds + data.length, data);
      return out;
    }

    Map<String, Object?> column(Map<String, Object?> h, String name) =>
        ((h['columns'] as List).firstWhere((c) => c['name'] == name) as Map)
            .cast<String, Object?>();

    void rejects(Uint8List bytes, String reason) => expect(
      () => snapshot.decode(bytes),
      throwsA(isA<FormatException>()),
      reason: reason,
    );

    rejects(Uint8List.fromList('nope'.codeUnits), 'magic');
    rejects(Uint8List(3), 'too short');
    rejects(Uint8List.fromList(good)..[4] = 2, 'newer version');
    rejects(Uint8List.fromList(good)..[4] = 0, 'version 0');
    rejects(
      Uint8List.fromList(good)
        ..buffer.asByteData().setUint32(8, 1 << 20, Endian.little),
      'header length',
    );
    rejects(Uint8List.fromList(good)..[12] = 0x7b + 1, 'header not JSON');
    rejects(good.sublist(0, good.length - 8), 'truncated data');
    rejects(patched((h, d) => h['rows'] = 3), 'length mismatch');
    rejects(patched((h, d) => h['rows'] = -1), 'negative rows');
    rejects(patched((h, d) => h.remove('schema')), 'no schema');
    rejects(
      patched((h, d) => (column(h, 'a')['codes'] as Map)['offset'] = 4),
      'unaligned',
    );
    rejects(
      patched((h, d) => (column(h, 'a')['codes'] as Map)['encoding'] = 'i64'),
      'unknown encoding',
    );
    rejects(
      patched((h, d) => (column(h, 'n')['data'] as Map)['encoding'] = 'f32'),
      'wrong encoding',
    );
    rejects(patched((h, d) => column(h, 'n')['type'] = 'blob'), 'unknown type');
    rejects(
      patched((h, d) => (column(h, 'a')['dictionary'] as Map)['count'] = 5),
      'dictionary count',
    );
    rejects(
      patched((h, d) => (h['columns'] as List).removeLast()),
      'schema column without data',
    );
    rejects(
      patched((h, d) {
        final codes = column(h, 'a')['codes'] as Map;
        d[codes['offset'] as int] = 7; // code 7 with a dictionary of 1
      }),
      'code out of range',
    );
    rejects(
      patched((h, d) {
        final data = column(h, 'b')['data'] as Map;
        d[data['offset'] as int] = 9;
      }),
      'invalid boolean',
    );
    rejects(
      patched((h, d) {
        final dict = column(h, 'a')['dictionary'] as Map;
        d[(dict['offset'] as int) + 4] = 0xff; // not UTF-8
      }),
      'dictionary not UTF-8',
    );
    // extra header keys are fine
    expect(
      snapshot.decode(patched((h, d) => h['source'] = 'x')).facts.rowCount,
      2,
    );
  });

  test('a foreign FactTable implementation is copied', () async {
    final f = await table(
      ['a', 'n'],
      [
        ['x', 1.5],
        ['y', null],
      ],
      {'a': ColumnType.text, 'n': ColumnType.number},
    );
    final back = snapshot.decode(snapshot.encode(_Wrapper(f))).facts;
    expectSameFacts(f, back);
  });
}

/// A FactTable that is not the engine's own implementation.
final class _Wrapper implements FactTable {
  _Wrapper(this.inner);
  final FactTable inner;

  @override
  Schema get schema => inner.schema;
  @override
  int get rowCount => inner.rowCount;
  @override
  List<FactColumn> get columns => inner.columns;
  @override
  FactColumn column(String name) => inner.column(name);
  @override
  FactColumn? findColumn(String name) => inner.findColumn(name);
  @override
  Object? valueAt(int row, String column) => inner.valueAt(row, column);
  @override
  Object? dimensionValue(int row, Dimension dimension) =>
      inner.dimensionValue(row, dimension);
  @override
  double? measureValue(int row, Measure measure) =>
      inner.measureValue(row, measure);
  @override
  List<Object?> distinctValues(Dimension dimension) =>
      inner.distinctValues(dimension);
  @override
  int countWhere(Dimension dimension, Object? value) =>
      inner.countWhere(dimension, value);
  @override
  FactTable withLabels(Map<String, String?> labels) => inner.withLabels(labels);
}
