import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tessera/tessera.dart';

Future<FactTable> sales() async {
  final bytes = File('test/data/sales.csv').readAsBytesSync();
  return (await loadFacts(CsvDataSource.fromData(bytes))).facts;
}

void main() {
  late FactTable f;
  setUpAll(() async => f = await sales());

  test('records keep the types, dates as ISO text', () {
    final first = const JsonFactExporter().records(f).first;
    expect(first.keys, f.columns.map((c) => c.name));
    expect(first['id'], isA<int>());
    expect(first['quantity'], anyOf(isA<int>(), isNull));
    expect(first['unit_price'], anyOf(isA<double>(), isNull));
    expect(first['date'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    expect(first['region'], isA<String>());
    final nulls = const JsonFactExporter()
        .records(f)
        .where((r) => r['country'] == null);
    expect(nulls, isNotEmpty);
  });

  test('a JSON Lines round trip reproduces the table', () async {
    final lines = const JsonFactExporter().exportLines(f);
    expect(lines.split('\n').where((l) => l.isNotEmpty).length, f.rowCount);
    final back = (await loadFacts(JsonlDataSource.fromString(lines))).facts;
    expect(back.rowCount, f.rowCount);
    expect(
      back.columns.map((c) => (c.name, c.type)),
      f.columns.map((c) => (c.name, c.type)),
    );
    for (final c in f.columns) {
      for (var r = 0; r < f.rowCount; r++) {
        expect(
          back.valueAt(r, c.name),
          f.valueAt(r, c.name),
          reason: '${c.name}[$r]',
        );
      }
    }
    // and the array form through JsonDataSource
    final array = (await loadFacts(
      JsonDataSource.fromString(const JsonFactExporter().export(f)),
    )).facts;
    expect(array.rowCount, f.rowCount);
    expect(array.valueAt(999, 'total'), f.valueAt(999, 'total'));
  });

  test('dateTime columns keep their time', () async {
    final source = ListDataSource(
      columns: ['t', 'flag'],
      rows: [
        ['2024-01-05T10:30:00', true],
        [null, null],
      ],
      declaredSchema: Schema([
        const ColumnSpec(name: 't', type: ColumnType.dateTime),
        const ColumnSpec(name: 'flag', type: ColumnType.boolean),
      ]),
    );
    final facts = (await loadFacts(source)).facts;
    final records = const JsonFactExporter().records(facts).toList();
    expect(records, [
      {'t': '2024-01-05T10:30:00.000Z', 'flag': true},
      {'t': null, 'flag': null},
    ]);
    final back = (await loadFacts(
      JsonlDataSource.fromString(const JsonFactExporter().exportLines(facts)),
    )).facts;
    expect(back.column('t').type, ColumnType.dateTime);
    expect(back.valueAt(0, 't'), DateTime.utc(2024, 1, 5, 10, 30));
    expect(back.column('flag').type, ColumnType.boolean);
  });

  test('columns, labels, indent, sink', () async {
    final labelled = f.withLabels({'unit_price': 'Unit price'});
    final e = const JsonFactExporter(
      columns: ['id', 'unit_price'],
      useLabels: true,
      indent: '  ',
    );
    final text = e.export(labelled);
    expect(text, startsWith('[\n  {\n    "id": 1,\n    "Unit price": '));
    final parsed = jsonDecode(text) as List;
    expect(parsed.length, f.rowCount);
    expect((parsed.first as Map).keys, ['id', 'Unit price']);
    final sink = StringBuffer();
    e.writeLines(sink, labelled);
    expect(
      sink.toString().split('\n').first,
      startsWith('{"id":1,"Unit price":'),
    );
    expect(
      () => const JsonFactExporter(columns: ['nope']).export(f),
      throwsArgumentError,
    );
    final empty = (await loadFacts(
      ListDataSource(
        columns: ['a'],
        rows: const [],
        declaredSchema: Schema([
          const ColumnSpec(name: 'a', type: ColumnType.text),
        ]),
      ),
    )).facts;
    expect(const JsonFactExporter().export(empty), '[]');
    expect(const JsonFactExporter().exportLines(empty), '');
  });
}
