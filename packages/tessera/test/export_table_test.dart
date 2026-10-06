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

  group('ExportTable', () {
    test('ofFacts: labels, names, types, every row by default', () {
      final table = ExportTable.ofFacts(f.withLabels({'region': 'Region'}));
      expect(table.columns.map((c) => c.name), f.columns.map((c) => c.name));
      expect(table.columns[2].header, 'Region');
      expect(table.columns[2].key, 'region');
      expect(table.columns[1].type, ColumnType.date);
      expect(table.rows.length, f.rowCount);
      expect(table.rows.first, [
        for (final c in f.columns) f.valueAt(0, c.name),
      ]);
      final named = ExportTable.ofFacts(f, useLabels: false);
      expect(named.columns.map((c) => c.header), f.columns.map((c) => c.name));
    });

    test('ofFacts: chosen columns, rows and a filter', () {
      final europe = ValueFilter(const ColumnDimension('region'), ['Europe']);
      final table = ExportTable.ofFacts(
        f,
        columns: ['total', 'region'],
        filter: europe,
      );
      expect(table.columns.map((c) => c.key), ['total', 'region']);
      final expected = [
        for (var r = 0; r < f.rowCount; r++)
          if (f.valueAt(r, 'region') == 'Europe') r,
      ];
      expect(table.rows.length, expected.length);
      expect(table.rows.every((row) => row[1] == 'Europe'), isTrue);
      // rows and filter combine
      final some = ExportTable.ofFacts(
        f,
        columns: ['id'],
        rows: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
        filter: europe,
      );
      expect(some.rows.map((r) => r.single), [
        for (final r in expected.where((r) => r < 10)) f.valueAt(r, 'id'),
      ]);
    });

    test('withColumn replaces one column by its key', () {
      final table = ExportTable.ofFacts(f).withColumn(
        'total',
        (c) => c.copyWith(numberFormat: const NumberFormat(decimals: 1)),
      );
      final total = table.columns.firstWhere((c) => c.key == 'total');
      expect(total.numberFormat, const NumberFormat(decimals: 1));
      expect(total.type, ColumnType.number);
      expect(table.columns.where((c) => c.numberFormat != null).length, 1);
      // plain columns are found by their header
      const plain = ExportTable([ExportColumn('A'), ExportColumn('B')], []);
      expect(
        plain.withColumn('B', (c) => c.copyWith(width: 9)).columns[1].width,
        9,
      );
    });

    test('showsTime follows the type, else the value', () {
      final midnight = DateTime.utc(2026, 3, 9);
      final noon = DateTime.utc(2026, 3, 9, 12);
      expect(const ExportColumn('x').showsTime(midnight), isFalse);
      expect(const ExportColumn('x').showsTime(noon), isTrue);
      const dateTime = ExportColumn('x', type: ColumnType.dateTime);
      expect(dateTime.showsTime(midnight), isTrue);
      const date = ExportColumn('x', type: ColumnType.date);
      expect(date.showsTime(noon), isFalse);
    });
  });

  group('CsvTableExporter', () {
    const columns = [
      ExportColumn('Name'),
      ExportColumn('Amount', numberFormat: NumberFormat(decimals: 2)),
      ExportColumn('Day'),
      ExportColumn('OK'),
    ];
    final rows = [
      ['Kovács, Anna', 1234.5, DateTime.utc(2026, 3, 9), true],
      ['say "hi"', 2.0, DateTime.utc(2026, 3, 9, 14, 30), false],
      [null, double.nan],
      [' padded\nlines', -7],
    ];

    test('header, plain values, quoting', () {
      final csv = const CsvTableExporter(
        options: CsvExportOptions(lineEnding: '\n'),
      ).export(ExportTable(columns, rows));
      expect(
        csv,
        'Name,Amount,Day,OK\n'
        '"Kovács, Anna",1234.5,2026-03-09,true\n'
        '"say ""hi""",2,2026-03-09T14:30:00.000Z,false\n'
        ',,,\n'
        '" padded\nlines",-7,,\n',
      );
    });

    test('options: european Excel, no header', () {
      final csv = const CsvTableExporter(
        options: CsvExportOptions.europeanExcel,
        header: false,
      ).export(ExportTable(columns, rows.take(1)));
      expect(csv, '﻿Kovács, Anna;1234,5;2026-03-09;true\r\n');
    });

    test('a CSV round trip reproduces the fact table', () async {
      final csv = const CsvTableExporter().export(
        ExportTable.ofFacts(f, useLabels: false),
      );
      final back = (await loadFacts(CsvDataSource.fromData(utf8.encode(csv))))
          .facts;
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
    });

    test('dateTime columns keep their time, date columns drop it', () {
      final csv =
          const CsvTableExporter(options: CsvExportOptions(lineEnding: '\n'))
              .export(
                ExportTable(
                  const [
                    ExportColumn('t', type: ColumnType.dateTime),
                    ExportColumn('d', type: ColumnType.date),
                  ],
                  [
                    [DateTime.utc(2024, 1, 5), DateTime.utc(2024, 1, 5, 10)],
                  ],
                ),
              );
      expect(csv, 't,d\n2024-01-05T00:00:00.000Z,2024-01-05\n');
    });
  });

  test('JsonFactExporter takes rows and a filter', () {
    final europe = ValueFilter(const ColumnDimension('region'), ['Europe']);
    final records = const JsonFactExporter(columns: ['id', 'region'])
        .records(f, rows: [for (var r = 0; r < 50; r++) r], filter: europe);
    expect(records, isNotEmpty);
    expect(records.every((r) => r['region'] == 'Europe'), isTrue);
    expect(
      records.length,
      [
        for (var r = 0; r < 50; r++)
          if (f.valueAt(r, 'region') == 'Europe') r,
      ].length,
    );
    final lines = const JsonFactExporter().exportLines(f, filter: europe);
    expect(
      lines.split('\n').where((l) => l.isNotEmpty).length,
      ExportTable.ofFacts(f, filter: europe).rows.length,
    );
  });
}
