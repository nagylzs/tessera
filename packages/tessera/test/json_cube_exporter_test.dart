import 'dart:convert';

import 'package:test/test.dart';
import 'package:tessera/tessera.dart';

const _rows = <List<Object?>>[
  ['Europe', 'Germany', '2024-01-05', 1, 10.0],
  ['Europe', 'Hungary', '2024-03-05', 2, 20.0],
  ['Europe', 'Germany', '2025-01-05', 4, null],
  ['Asia', 'Japan', '2024-06-05', 8, 50.0],
  [null, 'Iceland', '2024-02-01', 32, 70.0],
];

Future<FactTable> facts() async {
  final source = ListDataSource(
    columns: ['region', 'country', 'date', 'qty', 'price'],
    rows: _rows,
    declaredSchema: Schema([
      const ColumnSpec(name: 'region', type: ColumnType.text, label: 'Region'),
      const ColumnSpec(name: 'country', type: ColumnType.text),
      const ColumnSpec(name: 'date', type: ColumnType.date),
      const ColumnSpec(name: 'qty', type: ColumnType.integer),
      const ColumnSpec(name: 'price', type: ColumnType.number),
    ]),
  );
  return (await loadFacts(source)).facts;
}

const region = ColumnDimension('region');
const country = ColumnDimension('country');
const year = DatePartDimension('date', DatePart.year);
const quarter = DatePartDimension('date', DatePart.quarter);
final sumQty = Aggregate.sum(const Measure('qty'));
final avgPrice = Aggregate.average(const Measure('price'));

void main() {
  late FactTable f;
  late Cube cube;
  setUpAll(() async {
    f = await facts();
    cube =
        Cube(
              facts: f,
              spec: CubeSpec(
                rows: CubeAxis.of([region, country]),
                columns: CubeAxis.of([year, quarter]),
                aggregates: [sumQty, avgPrice],
              ),
            )
            .toggleRow(const DimensionPath([DimensionValue(region, 'Europe')]))
            .toggleColumn(const DimensionPath([DimensionValue(year, 2024)]));
  });

  test('records: one per grid row, named fields, JSON types', () {
    final records = const JsonCubeExporter().records(cube.layout);
    // rows: (empty), Asia, Europe, Germany, Hungary, Total
    expect(records.length, 6);
    final keys = records.first.keys.toList();
    expect(keys.take(2), ['Region', 'country']);
    expect(keys.skip(2).take(4), [
      '2024 / sum of qty',
      '2024 / avg of price',
      '2024 / Q1 / sum of qty',
      '2024 / Q1 / avg of price',
    ]);
    expect(keys.last, 'Total / avg of price');
    expect(keys.where((k) => k.startsWith('2025')), [
      '2025 / sum of qty',
      '2025 / avg of price',
    ]);
    expect(keys.toSet().length, keys.length);
    final empty = records[0];
    expect(empty['Region'], '(empty)');
    expect(empty['country'], isNull);
    expect(empty['2024 / sum of qty'], 32);
    expect(empty['2024 / Q1 / sum of qty'], 32);
    expect(empty['2025 / sum of qty'], isNull);
    final germany = records[3];
    expect(
      germany['Region'],
      'Europe',
      reason: 'group labels repeat by default',
    );
    expect(germany['country'], 'Germany');
    expect(germany['2024 / Q1 / sum of qty'], 1);
    expect(germany['2024 / Q1 / avg of price'], 10);
    expect(germany['2025 / sum of qty'], 4);
    expect(germany['2025 / avg of price'], isNull);
    expect(germany['Total / sum of qty'], 5);
    final total = records.last;
    expect(total['Region'], 'Total');
    expect(total['Total / sum of qty'], 47);
    expect(total['Total / avg of price'], 37.5);
    // integral doubles come out as ints, others as doubles
    expect(records[2]['Total / avg of price'], 15);
    expect(records[2]['Total / avg of price'], isA<int>());
  });

  test('origin labels, aggregate subset, custom separator and labels', () {
    final exporter = JsonCubeExporter(
      options: const JsonExportOptions(
        groupLabels: CsvGroupLabels.origin,
        pathSeparator: '|',
      ),
      emptyGroupLabel: '?',
      rowSummaryLabel: 'ALL',
      columnSummaryLabel: 'SUM',
    );
    final records = exporter.records(cube.layout, aggregates: [sumQty]);
    expect(records.first.keys.toList(), [
      'Region',
      'country',
      '2024|sum of qty',
      '2024|Q1|sum of qty',
      '2024|Q2|sum of qty',
      '2025|sum of qty',
      'SUM|sum of qty',
    ]);
    expect(records[0]['Region'], '?');
    expect(records[2]['Region'], 'Europe');
    expect(records[3]['Region'], isNull, reason: 'covered cell in origin mode');
    expect(records[3]['country'], 'Germany');
    expect(records.last['Region'], 'ALL');
  });

  test('JSON and JSON Lines text parse back to the records', () {
    const exporter = JsonCubeExporter();
    final records = exporter.records(cube.layout);
    expect(jsonDecode(exporter.export(cube.layout)), records);
    final pretty = JsonCubeExporter(
      options: const JsonExportOptions(indent: '  '),
    ).export(cube.layout);
    expect(pretty, startsWith('[\n  {\n    "Region"'));
    expect(jsonDecode(pretty), records);
    final lines = exporter.exportLines(cube.layout);
    expect(lines.endsWith('\n'), isTrue);
    final parsed = lines.trim().split('\n').map(jsonDecode).toList();
    expect(parsed, records);
    final sink = StringBuffer();
    exporter.writeLines(sink, cube.layout, aggregates: [avgPrice]);
    expect(sink.toString().split('\n').where((l) => l.isNotEmpty).length, 6);
    // and the JSON Lines import reads them straight back
    expect(JsonlDataSource.fromString(lines).rows().length, completion(6));
  });

  test('localized labels and dates', () async {
    final hu = JsonCubeExporter(strings: const TesseraStringsHu());
    final records = hu.records(cube.layout, aggregates: [sumQty]);
    expect(records.first.keys, contains('2024 / 1. n.év / qty összege'));
    expect(records.last['Region'], 'Összesen');
    expect(records[0]['Region'], '(üres)');
    // a date-valued row dimension is written as ISO text
    final byDate = Cube(
      facts: f,
      spec: CubeSpec(
        rows: CubeAxis.of([const ColumnDimension('date')]),
        aggregates: [sumQty],
      ),
    );
    final r = const JsonCubeExporter().records(byDate.layout);
    // what the sheet shows: the dimension's own formatting of the value
    expect(r.first['date'], '2024-01-05 00:00:00.000Z');
    expect(r.first.keys.last, 'Total / sum of qty');
  });

  test('colliding field names are made unique', () {
    final same = Cube(
      facts: f,
      spec: CubeSpec(
        rows: CubeAxis.of([const ColumnDimension('country', label: 'X')]),
        columns: CubeAxis.of([const ColumnDimension('region', label: 'X')]),
        aggregates: [Aggregate.count],
      ),
    );
    final keys = const JsonCubeExporter()
        .records(same.layout)
        .first
        .keys
        .toList();
    expect(keys.first, 'X');
    expect(keys.toSet().length, keys.length);
    final flat = Cube(
      facts: f,
      spec: CubeSpec(aggregates: [sumQty]),
    );
    final flatKeys = const JsonCubeExporter()
        .records(flat.layout)
        .first
        .keys
        .toList();
    expect(flatKeys, ['row', 'Total / sum of qty']);
  });
}
