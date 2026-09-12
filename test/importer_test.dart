import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tessera/tessera.dart';

ListDataSource src(
  List<String> columns,
  List<List<Object?>> rows, {
  Schema? schema,
}) => ListDataSource(columns: columns, rows: rows, declaredSchema: schema);

Schema schemaOf(Map<String, ColumnType> types) => Schema([
  for (final e in types.entries) ColumnSpec(name: e.key, type: e.value),
]);

void main() {
  group('FactTableImporter', () {
    test('imports typed values into typed columns', () async {
      final schema = schemaOf({
        'i': ColumnType.integer,
        'n': ColumnType.number,
        'b': ColumnType.boolean,
        'd': ColumnType.date,
        'dt': ColumnType.dateTime,
        't': ColumnType.text,
      });
      final result = await const FactTableImporter().import(
        src(
          ['i', 'n', 'b', 'd', 'dt', 't'],
          [
            [
              1,
              1.5,
              true,
              DateTime.utc(2025, 1, 1),
              DateTime.utc(2025, 1, 1, 8, 30),
              'a',
            ],
            [
              2,
              3,
              false,
              DateTime.utc(2025, 1, 2),
              DateTime.utc(2025, 1, 2),
              'b',
            ],
            [null, null, null, null, null, null],
            [
              3,
              2.5,
              true,
              DateTime.utc(2025, 1, 1),
              DateTime.utc(2025, 1, 1, 8, 30),
              'a',
            ],
          ],
        ),
        schema,
      );
      final f = result.facts;
      expect(f.rowCount, 4);
      expect(f.columns.map((c) => c.name), ['i', 'n', 'b', 'd', 'dt', 't']);
      expect(f.valueAt(0, 'i'), 1);
      expect(f.valueAt(0, 'i'), isA<int>());
      expect(f.valueAt(1, 'n'), 3.0);
      expect(f.valueAt(1, 'n'), isA<double>());
      expect(f.valueAt(1, 'b'), false);
      expect(f.valueAt(1, 'd'), DateTime.utc(2025, 1, 2));
      expect(f.valueAt(0, 'dt'), DateTime.utc(2025, 1, 1, 8, 30));
      expect(f.valueAt(3, 't'), 'a');
      for (final c in ['i', 'n', 'b', 'd', 'dt', 't']) {
        expect(f.valueAt(2, c), isNull, reason: c);
        expect(f.column(c).nullCount, 1, reason: c);
      }
      expect(f.column('i').distinctCount, 3);
      expect(f.column('t').distinctCount, 2);
      expect(f.column('d').distinctCount, 2);
      expect(result.report.hasIssues, isFalse);
      expect(result.report.rowsImported, 4);
    });

    test('parses text with the spec format, syntax and null values', () async {
      final schema = Schema([
        const ColumnSpec(
          name: 'd',
          type: ColumnType.date,
          format: 'dd.MM.yyyy',
        ),
        const ColumnSpec(
          name: 'n',
          type: ColumnType.number,
          numberSyntax: NumberSyntax.european,
          nullValues: {'', '?'},
        ),
        const ColumnSpec(name: 'b', type: ColumnType.boolean),
        const ColumnSpec(name: 't', type: ColumnType.text),
      ]);
      final result = await const FactTableImporter().import(
        src(
          ['d', 'n', 'b', 't'],
          [
            ['05.03.2025', '1.234,5', 'yes', ' keep spaces '],
            ['', '?', 'n/a', 'n/a'],
          ],
        ),
        schema,
      );
      final f = result.facts;
      expect(f.valueAt(0, 'd'), DateTime.utc(2025, 3, 5));
      expect(f.valueAt(0, 'n'), 1234.5);
      expect(f.valueAt(0, 'b'), true);
      expect(f.valueAt(0, 't'), ' keep spaces ');
      expect(f.valueAt(1, 'd'), isNull);
      expect(f.valueAt(1, 'n'), isNull);
      expect(f.valueAt(1, 'b'), isNull, reason: 'n/a is a default null value');
      expect(f.valueAt(1, 't'), isNull);
      expect(result.report.hasIssues, isFalse);
    });

    test(
      'date columns try the default formats when no format is set',
      () async {
        final result = await const FactTableImporter().import(
          src(
            ['d'],
            [
              ['2025-03-05'],
              ['2025-03-05 10:00:00'],
            ],
          ),
          schemaOf({'d': ColumnType.date}),
        );
        // second row has a time → widened to dateTime
        expect(result.facts.column('d').type, ColumnType.dateTime);
        expect(result.facts.valueAt(0, 'd'), DateTime.utc(2025, 3, 5));
        expect(result.facts.valueAt(1, 'd'), DateTime.utc(2025, 3, 5, 10));
        expect(result.report.widenedColumns, {'d': ColumnType.dateTime});
      },
    );

    test('widen: integer → number → text, converting stored values', () async {
      final result = await const FactTableImporter().import(
        src(
          ['c', 'k'],
          [
            ['1', '7'],
            ['2.5', '8'],
            ['x', '9'],
            ['4', '10'],
          ],
        ),
        schemaOf({'c': ColumnType.integer, 'k': ColumnType.integer}),
      );
      final f = result.facts;
      expect(f.column('c').type, ColumnType.text);
      expect(f.column('k').type, ColumnType.integer);
      expect(
        [for (var r = 0; r < 4; r++) f.valueAt(r, 'c')],
        ['1', '2.5', 'x', '4'],
      );
      expect(f.schema['c']!.type, ColumnType.text);
      expect(result.report.widenedColumns, {'c': ColumnType.text});
      expect(result.report.issues, isEmpty);
    });

    test('widen: integer → number keeps numeric values exact', () async {
      final result = await const FactTableImporter().import(
        src(
          ['c'],
          [
            ['1'],
            ['2.5'],
            [3],
          ],
        ),
        schemaOf({'c': ColumnType.integer}),
      );
      final f = result.facts;
      expect(f.column('c').type, ColumnType.number);
      expect([for (var r = 0; r < 3; r++) f.valueAt(r, 'c')], [1.0, 2.5, 3.0]);
      expect(f.measureValue(1, const Measure('c')), 2.5);
    });

    test('widen: boolean and date to text', () async {
      final result = await const FactTableImporter().import(
        src(
          ['b', 'd'],
          [
            ['true', '2025-01-01'],
            ['maybe', 'someday'],
          ],
        ),
        schemaOf({'b': ColumnType.boolean, 'd': ColumnType.date}),
      );
      final f = result.facts;
      expect(f.valueAt(0, 'b'), 'true');
      expect(f.valueAt(1, 'b'), 'maybe');
      expect(f.valueAt(0, 'd'), '2025-01-01');
      expect(f.valueAt(1, 'd'), 'someday');
    });

    test('nullify: counts, records and caps issues', () async {
      final result =
          await const FactTableImporter(
            policy: TypeMismatchPolicy.nullify,
            maxIssues: 1,
          ).import(
            src(
              ['c'],
              [
                ['1'],
                ['x'],
                ['y'],
              ],
            ),
            schemaOf({'c': ColumnType.integer}),
          );
      final f = result.facts;
      expect(f.column('c').type, ColumnType.integer);
      expect([for (var r = 0; r < 3; r++) f.valueAt(r, 'c')], [1, null, null]);
      expect(result.report.nullifiedPerColumn, {'c': 2});
      expect(result.report.issues.length, 1);
      expect(result.report.issues.single.row, 1);
      expect(result.report.issues.single.raw, 'x');
      expect(result.report.issuesTruncated, isTrue);
      expect(result.report.hasIssues, isTrue);
    });

    test('fail: throws on the first mismatch', () async {
      expect(
        () => const FactTableImporter(policy: TypeMismatchPolicy.fail).import(
          src(
            ['c'],
            [
              ['1'],
              ['x'],
            ],
          ),
          schemaOf({'c': ColumnType.integer}),
        ),
        throwsA(isA<ImportException>().having((e) => e.issue.row, 'row', 1)),
      );
    });

    test('custom parser, and a throwing parser is a mismatch', () async {
      final schema = Schema([
        ColumnSpec(
          name: 'p',
          type: ColumnType.integer,
          parser: (raw) => int.parse((raw as String).replaceAll('#', '')),
        ),
      ]);
      final result =
          await const FactTableImporter(policy: TypeMismatchPolicy.nullify)
              .import(
                src(
                  ['p'],
                  [
                    ['#12'],
                    ['bad'],
                  ],
                ),
                schema,
              );
      expect(result.facts.valueAt(0, 'p'), 12);
      expect(result.facts.valueAt(1, 'p'), isNull);
      expect(result.report.issues.single.message, startsWith('parser threw'));
    });

    test(
      'excluded columns are dropped; unknown columns are an error',
      () async {
        final schema = Schema([
          const ColumnSpec(name: 'a', type: ColumnType.integer),
          const ColumnSpec(name: 'b', type: ColumnType.integer, include: false),
        ]);
        final result = await const FactTableImporter().import(
          src(
            ['a', 'b'],
            [
              ['1', '2'],
            ],
          ),
          schema,
        );
        expect(result.facts.columns.map((c) => c.name), ['a']);
        expect(() => result.facts.column('b'), throwsArgumentError);
        expect(result.facts.schema.columns.map((c) => c.name), ['a']);

        expect(
          () => const FactTableImporter().import(
            src(['a'], []),
            schemaOf({'zzz': ColumnType.text}),
          ),
          throwsArgumentError,
        );
      },
    );

    test('empty source yields an empty table', () async {
      final result = await const FactTableImporter().import(
        src(['a'], []),
        schemaOf({'a': ColumnType.integer}),
      );
      expect(result.facts.rowCount, 0);
      expect(result.facts.column('a').nullCount, 0);
      expect(result.facts.distinctValues(const ColumnDimension('a')), isEmpty);
    });
  });

  group('FactTable', () {
    late FactTable facts;

    setUp(() async {
      facts = (await const FactTableImporter().import(
        src(
          ['region', 'date', 'qty'],
          [
            ['Europe', '2025-01-05', '2'],
            ['Asia', '2025-02-10', '3'],
            ['', '2025-01-20', ''],
            ['Europe', '', '5'],
          ],
        ),
        schemaOf({
          'region': ColumnType.text,
          'date': ColumnType.date,
          'qty': ColumnType.integer,
        }),
      )).facts;
    });

    test('dimension values, distinct values and counts', () {
      const region = ColumnDimension('region');
      const month = DatePartDimension('date', DatePart.month);
      expect(facts.dimensionValue(0, region), 'Europe');
      expect(facts.dimensionValue(2, region), isNull);
      expect(facts.dimensionValue(1, month), 2);
      expect(facts.dimensionValue(3, month), isNull);
      expect(facts.distinctValues(region), [null, 'Asia', 'Europe']);
      expect(facts.distinctValues(month), [null, 1, 2]);
      expect(facts.countWhere(region, 'Europe'), 2);
      expect(facts.countWhere(region, null), 1);
      expect(facts.countWhere(month, 1), 2);
    });

    test('measure values', () {
      const qty = Measure('qty');
      expect(facts.measureValue(0, qty), 2.0);
      expect(facts.measureValue(2, qty), isNull);
      expect(
        () => facts.measureValue(0, const Measure('region')),
        throwsArgumentError,
      );
    });

    test('column metadata', () {
      expect(facts.column('region').nullCount, 1);
      expect(facts.column('region').distinctCount, 2);
      expect(facts.column('qty').nullCount, 1);
      expect(facts.column('qty').distinctCount, 3);
      expect(facts.column('date').type, ColumnType.date);
    });
  });

  test('loadFacts imports example/assets/sales.csv end to end', () async {
    final file = File('example/assets/sales.csv');
    final result = await loadFacts(
      CsvDataSource.fromBytes(file.openRead, name: 'sales.csv'),
    );
    final f = result.facts;
    expect(f.rowCount, 1000);
    expect(result.report.hasIssues, isFalse);
    expect(
      {for (final c in f.columns) c.name: c.type},
      {
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
      },
    );
    // Null counts as verified when the file was generated.
    expect(f.column('country').nullCount, 47);
    expect(f.column('region').nullCount, 89);
    expect(f.column('category').nullCount, 47 + 152);
    expect(f.column('product').nullCount, 47 + 47);
    expect(f.column('quantity').nullCount, 38);
    expect(f.column('unit_price').nullCount, 44);
    expect(f.column('total').nullCount, 82);
    expect(f.column('discount').nullCount, 149);
    expect(f.column('salesperson').nullCount, 32);
    // Row id 4: Argentina, Mouse, no unit_price → no total.
    expect(f.valueAt(3, 'id'), 4);
    expect(f.valueAt(3, 'country'), 'Argentina');
    expect(f.valueAt(3, 'unit_price'), isNull);
    expect(f.valueAt(3, 'total'), isNull);
    expect(f.valueAt(3, 'quantity'), 20);
    expect(f.valueAt(3, 'date'), DateTime.utc(2025, 4, 6));
    // Hierarchy sanity: Iceland never has a region.
    const region = ColumnDimension('region');
    expect(f.distinctValues(region).length, 7);
    expect(f.distinctValues(region).first, isNull);
    expect(f.distinctValues(const DatePartDimension('date', DatePart.year)), [
      2024,
      2025,
    ]);
    var icelandWithRegion = 0;
    for (var r = 0; r < f.rowCount; r++) {
      if (f.valueAt(r, 'country') == 'Iceland' &&
          f.valueAt(r, 'region') != null) {
        icelandWithRegion++;
      }
    }
    expect(icelandWithRegion, 0);
  });
}
