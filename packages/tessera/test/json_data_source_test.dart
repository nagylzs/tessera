import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tessera/tessera.dart';

const _doc = '''
[
  {"region": "Europe", "country": "Germany", "date": "2024-01-05", "qty": 1, "price": 10.5, "active": true,
   "address": {"city": "Berlin", "geo": {"lat": 52.5}}, "tags": ["a", "b"]},
  {"region": "Europe", "country": null, "date": "2024-03-05", "qty": 2, "price": 20, "active": false,
   "address": {"city": "Paris"}, "extra": "later key"},
  {"region": "Asia", "qty": 5.5, "price": null, "note": {"x": 1}}
]
''';

Future<List<SourceRow>> all(DataSource s) => s.rows().toList();

void main() {
  group('JsonDataSource', () {
    test('columns are the union of keys, nested objects flattened', () async {
      final s = JsonDataSource.fromString(_doc, name: 'test.json');
      expect(await s.columnNames(), [
        'region',
        'country',
        'date',
        'qty',
        'price',
        'active',
        'address.city',
        'address.geo.lat',
        'tags',
        'extra',
        'note.x',
      ]);
      final rows = await all(s);
      expect(rows.length, 3);
      expect(rows[0], [
        'Europe',
        'Germany',
        '2024-01-05',
        1,
        10.5,
        true,
        'Berlin',
        52.5,
        '["a","b"]',
        null,
        null,
      ]);
      expect(rows[1], [
        'Europe',
        null,
        '2024-03-05',
        2,
        20,
        false,
        'Paris',
        null,
        null,
        'later key',
        null,
      ]);
      expect(rows[2], [
        'Asia',
        null,
        null,
        5.5,
        null,
        null,
        null,
        null,
        null,
        null,
        1,
      ]);
      expect(await s.estimatedRowCount(), 3);
      expect(s.declaredSchema, isNull);
      expect(s.name, 'test.json');
      // re-readable
      expect((await all(s)).length, 3);
    });

    test(
      'flatten off keeps nested objects as JSON text; explicit columns',
      () async {
        final s = JsonDataSource.fromString(
          _doc,
          options: const JsonOptions(flatten: false),
        );
        expect(await s.columnNames(), [
          'region',
          'country',
          'date',
          'qty',
          'price',
          'active',
          'address',
          'tags',
          'extra',
          'note',
        ]);
        final rows = await all(s);
        expect(rows[0][6], '{"city":"Berlin","geo":{"lat":52.5}}');
        expect(rows[2][9], '{"x":1}');
        final picked = JsonDataSource.fromString(
          _doc,
          options: const JsonOptions(
            columns: ['qty', 'missing', 'address.city'],
          ),
        );
        expect(await picked.columnNames(), ['qty', 'missing', 'address.city']);
        expect(await all(picked), [
          [1, null, 'Berlin'],
          [2, null, 'Paris'],
          [5.5, null, null],
        ]);
        final custom = JsonDataSource.fromString(
          _doc,
          options: const JsonOptions(separator: '/'),
        );
        expect(await custom.columnNames(), contains('address/geo/lat'));
      },
    );

    test('bytes and streams', () async {
      final bytes = utf8.encode('[{"a": "árvíztűrő", "b": 1}]');
      expect(await all(JsonDataSource.fromData(bytes)), [
        ['árvíztűrő', 1],
      ]);
      var opened = 0;
      final streamed = JsonDataSource.fromBytes(() {
        opened++;
        return Stream.fromIterable([bytes.sublist(0, 7), bytes.sublist(7)]);
      });
      expect(await all(streamed), [
        ['árvíztűrő', 1],
      ]);
      expect(await all(streamed), [
        ['árvíztűrő', 1],
      ]);
      expect(opened, 1, reason: 'decoded once, then cached');
    });

    test('errors name the problem', () async {
      expect(
        () => all(JsonDataSource.fromString('{"a": 1}', name: 'x')),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('x: expected a JSON array of objects'),
          ),
        ),
      );
      expect(
        () => all(JsonDataSource.fromString('[1, 2]', name: 'x')),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('x: element 0: expected an object, got a number'),
          ),
        ),
      );
      expect(
        () => all(JsonDataSource.fromString('[{"a": }]', name: 'x')),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            startsWith('x: '),
          ),
        ),
      );
      expect(await all(JsonDataSource.fromString('[]')), isEmpty);
      expect(await JsonDataSource.fromString('[]').columnNames(), isEmpty);
    });

    test('imports with inferred types', () async {
      final facts = (await loadFacts(JsonDataSource.fromString(_doc))).facts;
      expect(facts.column('qty').type, ColumnType.number); // 1, 2, 5.5
      expect(facts.column('price').type, ColumnType.number);
      expect(facts.column('date').type, ColumnType.date);
      expect(facts.column('active').type, ColumnType.boolean);
      expect(facts.column('address.geo.lat').type, ColumnType.number);
      expect(facts.column('note.x').type, ColumnType.integer);
      expect(facts.valueAt(0, 'date'), DateTime.utc(2024, 1, 5));
      expect(facts.valueAt(1, 'country'), isNull);
      expect(facts.valueAt(0, 'tags'), '["a","b"]');
      final cube = Cube(
        facts: facts,
        spec: CubeSpec(
          rows: CubeAxis.of([const ColumnDimension('region')]),
          aggregates: [Aggregate.sum(const Measure('qty'))],
        ),
      );
      expect(
        cube.layout.cellAt(0, 0).aggregate(Aggregate.sum(const Measure('qty'))),
        5.5,
      ); // Asia
      expect(
        cube.layout.cellAt(1, 0).aggregate(Aggregate.sum(const Measure('qty'))),
        3.0,
      ); // Europe
    });
  });

  group('JsonlDataSource', () {
    const lines =
        '{"a": 1, "b": "x"}\r\n\n{"a": 2, "b": null, "c": true}\n   \n{"a": 3}\n';

    test('streams lines, columns from the first record', () async {
      final s = JsonlDataSource.fromString(lines);
      expect(await s.columnNames(), ['a', 'b']);
      expect(await all(s), [
        [1, 'x'],
        [2, null],
        [3, null],
      ]);
      expect(await s.estimatedRowCount(), 3);
    });

    test('scanAllRows unions the keys; explicit columns', () async {
      final s = JsonlDataSource.fromString(
        lines,
        options: const JsonOptions(scanAllRows: true),
      );
      expect(await s.columnNames(), ['a', 'b', 'c']);
      expect(await all(s), [
        [1, 'x', null],
        [2, null, true],
        [3, null, null],
      ]);
      final picked = JsonlDataSource.fromString(
        lines,
        options: const JsonOptions(columns: ['c', 'a']),
      );
      expect(await all(picked), [
        [null, 1],
        [true, 2],
        [null, 3],
      ]);
    });

    test('nested values flatten like the array source', () async {
      final s = JsonlDataSource.fromString(
        '{"p": {"q": {"r": 1}}, "l": [1, {"m": 2}]}\n',
      );
      expect(await s.columnNames(), ['p.q.r', 'l']);
      expect(await all(s), [
        [1, '[1,{"m":2}]'],
      ]);
    });

    test('bytes, chunked streams and the row estimate', () async {
      final text = StringBuffer();
      for (var i = 0; i < 1000; i++) {
        text.writeln('{"i": $i, "name": "row number $i"}');
      }
      final bytes = utf8.encode(text.toString());
      final data = JsonlDataSource.fromData(bytes);
      expect((await all(data)).length, 1000);
      // the estimate uses the first 200 lines and the total length
      final estimate = (await data.estimatedRowCount())!;
      expect(estimate, closeTo(1000, 60));
      var opened = 0;
      final streamed = JsonlDataSource.fromBytes(() {
        opened++;
        return Stream.fromIterable([
          for (var i = 0; i < bytes.length; i += 1000)
            bytes.sublist(i, i + 1000 > bytes.length ? bytes.length : i + 1000),
        ]);
      }, length: bytes.length);
      expect((await all(streamed)).length, 1000);
      expect(opened, greaterThanOrEqualTo(2), reason: 'reopened per read');
      expect(
        await JsonlDataSource.fromBytes(() => Stream.value(bytes))
            .estimatedRowCount(),
        isNull,
      );
      expect(await JsonlDataSource.fromString('').estimatedRowCount(), 0);
    });

    test('errors name the line', () async {
      expect(
        () => all(JsonlDataSource.fromString('{"a": 1}\n[1]\n', name: 'f')),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('f, line 2: expected an object, got an array'),
          ),
        ),
      );
      expect(
        () =>
            all(JsonlDataSource.fromString('{"a": 1}\n\n{oops}\n', name: 'f')),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            startsWith('f, line 3: '),
          ),
        ),
      );
    });
  });

  test('sales.csv survives a CSV → JSON → import round trip', () async {
    final bytes = File('test/data/sales.csv').readAsBytesSync();
    final csv = CsvDataSource.fromData(bytes);
    final fromCsv = (await loadFacts(csv)).facts;
    // the CSV rows as JSON objects (strings stay strings; JSON has no dates)
    final names = await csv.columnNames();
    final objects = [
      await for (final row in csv.rows())
        {for (var i = 0; i < names.length; i++) names[i]: row[i]},
    ];
    final json = JsonDataSource.fromData(utf8.encode(jsonEncode(objects)));
    final jsonl = JsonlDataSource.fromString(
      objects.map(jsonEncode).join('\n'),
    );
    for (final source in [json, jsonl]) {
      final facts = (await loadFacts(source)).facts;
      expect(facts.rowCount, fromCsv.rowCount);
      expect(
        facts.columns.map((c) => (c.name, c.type)),
        fromCsv.columns.map((c) => (c.name, c.type)),
      );
      for (final c in fromCsv.columns) {
        for (var r = 0; r < fromCsv.rowCount; r++) {
          expect(
            facts.valueAt(r, c.name),
            fromCsv.valueAt(r, c.name),
            reason: '${source.name} ${c.name}[$r]',
          );
        }
      }
    }
  });
}
