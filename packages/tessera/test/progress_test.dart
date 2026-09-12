import 'dart:io';

import 'package:test/test.dart';
import 'package:tessera/tessera.dart';

ListDataSource numbers(int n) => ListDataSource(
  columns: ['n'],
  rows: [
    for (var i = 0; i < n; i++) [i],
  ],
  declaredSchema: Schema([
    const ColumnSpec(name: 'n', type: ColumnType.integer),
  ]),
);

void main() {
  group('estimatedRowCount', () {
    test('list sources are exact', () async {
      expect(await numbers(25).estimatedRowCount(), 25);
      expect(await numbers(0).estimatedRowCount(), 0);
    });

    test('csv from string estimates from the first records', () async {
      final text = File('test/data/sales.csv').readAsStringSync();
      final estimate = await CsvDataSource.fromString(text).estimatedRowCount();
      expect(estimate, closeTo(1000, 60));
      // short sources are exact
      expect(
        await CsvDataSource.fromString('a,b\n1,2\n3,4\n').estimatedRowCount(),
        2,
      );
      expect(
        await CsvDataSource.fromString(
          '1,2\n3,4\n',
          options: const CsvOptions(hasHeader: false),
        ).estimatedRowCount(),
        2,
      );
      expect(await CsvDataSource.fromString('').estimatedRowCount(), 0);
      expect(await CsvDataSource.fromString('a,b\n').estimatedRowCount(), 0);
    });

    test('csv from bytes needs a length', () async {
      final file = File('test/data/sales.csv');
      expect(
        await CsvDataSource.fromBytes(file.openRead).estimatedRowCount(),
        isNull,
      );
      final source = CsvDataSource.fromBytes(
        file.openRead,
        length: file.lengthSync(),
      );
      final estimate = await source.estimatedRowCount();
      expect(estimate, closeTo(1000, 60));
      expect(await source.estimatedRowCount(), estimate, reason: 'cached');
    });
  });

  group('import progress', () {
    test('reports every progressEvery rows and once when done', () async {
      final reports = <ImportProgress>[];
      final result = await const FactTableImporter(progressEvery: 10).import(
        numbers(25),
        numbers(25).declaredSchema!,
        onProgress: (p) {
          reports.add(p);
          return true;
        },
      );
      expect(result.facts.rowCount, 25);
      expect(reports.map((p) => p.rowsRead), [10, 20, 25]);
      expect(reports.map((p) => p.estimatedTotal), [25, 25, 25]);
      expect(reports.map((p) => p.done), [false, false, true]);
      expect(reports.map((p) => p.fraction), [0.4, 0.8, 1.0]);
    });

    test('fraction is capped below 1 until done and null without a total', () {
      expect(
        const ImportProgress(rowsRead: 500, estimatedTotal: 400).fraction,
        0.99,
      );
      expect(
        const ImportProgress(rowsRead: 500, estimatedTotal: null).fraction,
        isNull,
      );
      expect(
        const ImportProgress(
          rowsRead: 500,
          estimatedTotal: null,
          done: true,
        ).fraction,
        1,
      );
      expect(
        const ImportProgress(rowsRead: 0, estimatedTotal: 0).fraction,
        isNull,
      );
    });

    test(
      'no reports without a callback; a tiny source only reports done',
      () async {
        var calls = 0;
        await loadFacts(
          numbers(3),
          onProgress: (p) {
            calls++;
            expect(p.done, isTrue);
            expect(p.rowsRead, 3);
            return true;
          },
        );
        expect(calls, 1);
      },
    );

    test('returning false cancels', () async {
      expect(
        () => const FactTableImporter(progressEvery: 10).import(
          numbers(25),
          numbers(25).declaredSchema!,
          onProgress: (p) => p.rowsRead < 20,
        ),
        throwsA(
          isA<ImportCancelled>().having((e) => e.rowsRead, 'rowsRead', 20),
        ),
      );
    });
  });

  group('loadFactsInIsolate', () {
    test('imports a file in another isolate with progress', () async {
      final file = File('test/data/sales.csv');
      final source = CsvDataSource.fromBytes(
        file.openRead,
        length: file.lengthSync(),
      );
      final reports = <ImportProgress>[];
      final result = await loadFactsInIsolate(
        source,
        importer: const FactTableImporter(progressEvery: 300),
        onProgress: (p) {
          reports.add(p);
          return true;
        },
      );
      expect(result.facts.rowCount, 1000);
      expect(result.facts.column('total').type, ColumnType.number);
      expect(result.facts.valueAt(3, 'country'), 'Argentina');
      expect(reports.map((p) => p.rowsRead), [300, 600, 900, 1000]);
      expect(reports.last.done, isTrue);
      expect(reports.first.estimatedTotal, closeTo(1000, 60));
    });

    test('works with in-memory bytes and a given schema', () async {
      final bytes = File('test/data/sales.csv').readAsBytesSync();
      final source = CsvDataSource.fromBytes(
        () => Stream.value(bytes),
        length: bytes.length,
      );
      final schema = (await inferSchema(source))
          .replace(const ColumnSpec(name: 'quantity', type: ColumnType.text));
      final result = await loadFactsInIsolate(source, schema: schema);
      expect(result.facts.column('quantity').type, ColumnType.text);
      expect(result.facts.rowCount, 1000);
    });

    test('can be cancelled from the caller', () async {
      // Cancellation is a message to the worker, so it takes effect at one
      // of the following progress reports; use a source big enough for that.
      final text = StringBuffer('n,m\n');
      for (var i = 0; i < 300000; i++) {
        text.writeln('$i,${i * 2}');
      }
      final source = CsvDataSource.fromString(text.toString());
      var reports = 0;
      await expectLater(
        loadFactsInIsolate(
          source,
          importer: const FactTableImporter(progressEvery: 1000),
          onProgress: (p) {
            reports++;
            return reports < 2;
          },
        ),
        throwsA(
          isA<ImportCancelled>().having(
            (e) => e.rowsRead,
            'rowsRead',
            lessThan(300000),
          ),
        ),
      );
    });
  });
}
