import 'dart:io';

import 'package:test/test.dart';
import 'package:tessera/tessera.dart';

Map<String, ColumnType> typesOf(Schema s) => {
  for (final c in s.columns) c.name: c.type,
};

void main() {
  test('structureKey is the JSON list of column names, in order', () {
    const a = ColumnSpec(name: 'region', type: ColumnType.text);
    const b = ColumnSpec(name: 'amount', type: ColumnType.number);
    expect(Schema([a, b]).structureKey, '["region","amount"]');
    expect(Schema([b, a]).structureKey, '["amount","region"]');
    // Types, labels and exclusion do not matter, only names and order.
    expect(
      Schema([
        a.copyWith(type: ColumnType.integer, label: 'Region', include: false),
        b,
      ]).structureKey,
      Schema([a, b]).structureKey,
    );
    expect(Schema([]).structureKey, '[]');
  });

  group('NumberSyntax', () {
    test('standard integers and numbers', () {
      const s = NumberSyntax.standard;
      expect(s.parseInteger(' 42 '), 42);
      expect(s.parseInteger('-7'), -7);
      expect(s.parseInteger('1,234,567'), 1234567);
      expect(s.parseInteger('12,34'), isNull);
      expect(s.parseInteger('1.5'), isNull);
      expect(s.parseInteger('0x1F'), isNull);
      expect(s.parseInteger(''), isNull);
      expect(s.parseNumber('1.5'), 1.5);
      expect(s.parseNumber('.5'), 0.5);
      expect(s.parseNumber('1,234.5'), 1234.5);
      expect(s.parseNumber('1e3'), 1000);
      expect(s.parseNumber('42'), 42);
      expect(s.parseNumber('NaN'), isNull);
      expect(s.parseNumber('Infinity'), isNull);
      expect(s.parseNumber('1.2.3'), isNull);
      expect(s.parseNumber('abc'), isNull);
    });

    test('fast and full paths agree on edge cases', () {
      const std = NumberSyntax.standard;
      const eu = NumberSyntax.european;
      expect(std.parseInteger('+5'), 5);
      expect(std.parseInteger('-'), isNull);
      expect(std.parseInteger('+'), isNull);
      expect(std.parseInteger('007'), 7);
      expect(std.parseInteger('123456789012345678'), 123456789012345678);
      expect(std.parseInteger('9223372036854775807'), 9223372036854775807);
      expect(std.parseInteger('1_000'), isNull);
      expect(std.parseNumber('5.'), 5);
      expect(std.parseNumber('-.5'), -0.5);
      expect(std.parseNumber('1e'), isNull);
      expect(std.parseNumber('e5'), isNull);
      expect(std.parseNumber('1e-3'), 0.001);
      expect(std.parseNumber('1E+3'), 1000);
      expect(std.parseNumber('--1'), isNull);
      expect(std.parseNumber('1-'), isNull);
      expect(std.parseNumber('1.2.3'), isNull);
      expect(std.parseNumber('+'), isNull);
      expect(std.parseNumber('.'), isNull);
      expect(eu.parseNumber('1,5e2'), 150);
      expect(eu.parseNumber('1.5'), isNull);
      expect(eu.parseNumber('-0,5'), -0.5);
      expect(eu.parseInteger('12'), 12);
      expect(std.parseNumber('1e400'), isNull);
    });

    test('european syntax', () {
      const s = NumberSyntax.european;
      expect(s.parseNumber('1.234,56'), 1234.56);
      expect(s.parseNumber('1 234,56'), 1234.56);
      expect(s.parseNumber('1 234'), 1234);
      expect(s.parseInteger('1.234'), 1234);
      expect(s.parseNumber('3,14'), 3.14);
      expect(s.parseNumber('3.14'), isNull);
    });
  });

  test('parseBoolean', () {
    expect(parseBoolean('true'), isTrue);
    expect(parseBoolean(' No '), isFalse);
    expect(parseBoolean('YES'), isTrue);
    expect(parseBoolean('1'), isNull);
    expect(parseBoolean(''), isNull);
  });

  group('DatePattern', () {
    test('iso date', () {
      final p = DatePattern.of('yyyy-MM-dd');
      expect(p.hasTime, isFalse);
      expect(p.parse('2025-03-05'), DateTime.utc(2025, 3, 5));
      expect(p.parse('2025-3-5'), isNull);
      expect(p.parse('2025-02-30'), isNull);
      expect(p.parse('2025-13-01'), isNull);
      expect(p.parse('2025-03-05x'), isNull);
      expect(p.parse('2025-03-05 10:00'), isNull);
    });

    test('hungarian and single-digit tokens', () {
      expect(
        DatePattern.of('yyyy.MM.dd.').parse('2025.03.05.'),
        DateTime.utc(2025, 3, 5),
      );
      expect(
        DatePattern.of('d/M/yyyy').parse('5/3/2025'),
        DateTime.utc(2025, 3, 5),
      );
      expect(
        DatePattern.of('d/M/yyyy').parse('25/12/2025'),
        DateTime.utc(2025, 12, 25),
      );
      expect(
        DatePattern.of('dd.MM.yy').parse('05.03.25'),
        DateTime.utc(2025, 3, 5),
      );
    });

    test('time fields', () {
      final p = DatePattern.of('yyyy-MM-ddTHH:mm:ss');
      expect(p.hasTime, isTrue);
      expect(
        p.parse('2025-03-05T14:22:11'),
        DateTime.utc(2025, 3, 5, 14, 22, 11),
      );
      expect(p.parse('2025-03-05T24:00:00'), isNull);
      expect(
        DatePattern.of('HH:mm:ss.SSS').parse('01:02:03.5'),
        DateTime.utc(1, 1, 1, 1, 2, 3, 500),
      );
    });

    test('instances are cached', () {
      expect(
        identical(DatePattern.of('yyyy-MM-dd'), DatePattern.of('yyyy-MM-dd')),
        isTrue,
      );
    });
  });

  group('inferSchema', () {
    ListDataSource text(List<String> columns, List<List<Object?>> rows) =>
        ListDataSource(columns: columns, rows: rows);

    test('picks the narrowest type per column', () async {
      final schema = await inferSchema(
        text(
          ['i', 'n', 'b', 'd', 'dt', 't', 'mixed', 'empty'],
          [
            [
              '1',
              '1.5',
              'true',
              '2025-01-01',
              '2025-01-01 10:00:00',
              'a',
              '1',
              '',
            ],
            [
              '2',
              '2',
              'no',
              '2025-02-28',
              '2025-01-02 11:30:00',
              '2',
              '1.5',
              'n/a',
            ],
            ['-3', '1e3', 'YES', '', 'NULL', '2025-01-01', 'x', ''],
          ],
        ),
      );
      expect(typesOf(schema), {
        'i': ColumnType.integer,
        'n': ColumnType.number,
        'b': ColumnType.boolean,
        'd': ColumnType.date,
        'dt': ColumnType.dateTime,
        't': ColumnType.text,
        'mixed': ColumnType.text,
        'empty': ColumnType.text,
      });
      expect(schema['d']!.format, 'yyyy-MM-dd');
      expect(schema['dt']!.format, 'yyyy-MM-dd HH:mm:ss');
      expect(schema['t']!.format, isNull);
      expect(schema['i']!.numberSyntax, NumberSyntax.standard);
    });

    test('uses the given date formats and number syntax', () async {
      final schema = await inferSchema(
        text(
          ['d', 'n'],
          [
            ['05.03.2025', '1.234,5'],
            ['31.12.2024', '7'],
          ],
        ),
        options: const InferenceOptions(
          dateFormats: ['yyyy-MM-dd', 'dd.MM.yyyy'],
          numberSyntax: NumberSyntax.european,
        ),
      );
      expect(schema['d']!.type, ColumnType.date);
      expect(schema['d']!.format, 'dd.MM.yyyy');
      expect(schema['n']!.type, ColumnType.number);
      expect(schema['n']!.numberSyntax, NumberSyntax.european);
    });

    test('only samples sampleRows rows', () async {
      final rows = [
        for (var i = 0; i < 20; i++) ['$i'],
        ['oops'],
      ];
      final all = await inferSchema(text(['c'], rows));
      expect(all['c']!.type, ColumnType.text);
      final sampled = await inferSchema(
        text(['c'], rows),
        options: const InferenceOptions(sampleRows: 20),
      );
      expect(sampled['c']!.type, ColumnType.integer);
    });

    test('classifies typed cells by Dart type', () async {
      final schema = await inferSchema(
        text(
          ['i', 'n', 'b', 'd', 'dt', 'mixed', 'obj'],
          [
            [
              1,
              1.5,
              true,
              DateTime.utc(2025, 1, 1),
              DateTime.utc(2025, 1, 1, 8),
              1,
              Object(),
            ],
            [
              2,
              2.0,
              false,
              DateTime.utc(2025, 1, 2),
              DateTime.utc(2025, 1, 2),
              '3',
              'x',
            ],
            [null, null, null, null, null, 2.5, null],
          ],
        ),
      );
      expect(typesOf(schema), {
        'i': ColumnType.integer,
        'n': ColumnType.number,
        'b': ColumnType.boolean,
        'd': ColumnType.date,
        'dt': ColumnType.dateTime,
        'mixed': ColumnType.number,
        'obj': ColumnType.text,
      });
      expect(schema['d']!.format, isNull);
    });

    test('returns a declared schema untouched', () async {
      final declared = Schema([
        const ColumnSpec(name: 'a', type: ColumnType.boolean),
      ]);
      final source = ListDataSource(
        columns: ['a'],
        rows: [
          ['42'],
        ],
        declaredSchema: declared,
      );
      expect(identical(await inferSchema(source), declared), isTrue);
    });

    test('short rows count as null', () async {
      final schema = await inferSchema(
        text(
          ['a', 'b'],
          [
            ['1'],
            ['2', '3'],
          ],
        ),
      );
      expect(schema['b']!.type, ColumnType.integer);
    });

    test('infers the example sales.csv', () async {
      final file = File('test/data/sales.csv');
      final source = CsvDataSource.fromBytes(file.openRead, name: 'sales.csv');
      final schema = await inferSchema(source);
      expect(typesOf(schema), {
        'id': ColumnType.integer,
        'date': ColumnType.date,
        'region': ColumnType.text,
        'country': ColumnType.text,
        'category': ColumnType.text,
        'product': ColumnType.text,
        'salesperson': ColumnType.text,
        'quantity': ColumnType.integer,
        'unit_price': ColumnType.number,
        'discount': ColumnType.number,
        'total': ColumnType.number,
      });
      expect((await source.rows().length), 1000);
    });
  });
}
