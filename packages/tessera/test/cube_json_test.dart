import 'dart:convert';

import 'package:test/test.dart';
import 'package:tessera/tessera.dart';

/// region, country, date, qty, price, active
const _rows = <List<Object?>>[
  ['Europe', 'Germany', '2024-01-05', 1, 10.0, true],
  ['Europe', 'Hungary', '2024-03-05', 2, 20.0, false],
  ['Europe', null, '2025-01-05', 3, null, null],
  ['Asia', 'Japan', '2025-06-05', 5, 50.0, true],
  [null, 'Iceland', null, null, 70.0, false],
];

final declared = Schema([
  const ColumnSpec(name: 'region', type: ColumnType.text),
  const ColumnSpec(name: 'country', type: ColumnType.text, label: 'Country'),
  const ColumnSpec(name: 'date', type: ColumnType.date, format: 'yyyy-MM-dd'),
  const ColumnSpec(name: 'qty', type: ColumnType.integer),
  const ColumnSpec(
    name: 'price',
    type: ColumnType.number,
    numberSyntax: NumberSyntax.european,
    nullValues: {'', '?'},
  ),
  const ColumnSpec(name: 'active', type: ColumnType.boolean, include: false),
]);

Future<FactTable> facts() async {
  final source = ListDataSource(
    columns: ['region', 'country', 'date', 'qty', 'price', 'active'],
    rows: _rows,
    declaredSchema: declared,
  );
  return (await loadFacts(source)).facts;
}

const region = ColumnDimension('region');
const country = ColumnDimension('country', label: 'Land');
const year = DatePartDimension('date', DatePart.year);
const month = DatePartDimension('date', DatePart.month, label: 'Monat');
final size = ExpressionDimension(
  'if(qty > 2, "big", "small")',
  id: 'size',
  label: 'Size',
);
const qty = Measure('qty');
const price = Measure('price', label: 'Price');
final net = Measure.expression('qty * price', id: 'net', label: 'Net');

/// Through text, so only JSON-representable data survives.
Object? viaText(Object? json) => jsonDecode(jsonEncode(json));

final richSpec = CubeSpec(
  rows: CubeAxis(
    dimensions: [
      AxisDimension(
        region,
        sort: const AxisSort(
          direction: SortDirection.descending,
          nulls: NullPosition.last,
        ),
      ),
      AxisDimension(
        country,
        sort: AxisSort(
          by: SortBy.aggregate,
          aggregate: Aggregate.sum(qty),
          keyPath: const DimensionPath([DimensionValue(year, 2024)]),
        ),
      ),
      AxisDimension(size),
    ],
    summaryPosition: SummaryPosition.start,
    subtotalPosition: SubtotalPosition.bottom,
  ),
  columns: CubeAxis(
    dimensions: const [AxisDimension(year), AxisDimension(month)],
    summaryPosition: SummaryPosition.hidden,
    subtotalPosition: SubtotalPosition.hidden,
  ),
  aggregates: [
    Aggregate.sum(qty),
    Aggregate.average(price),
    Aggregate.min(net),
    Aggregate.max(qty),
    Aggregate.countNonNull(price),
    Aggregate.stdDev(qty),
    Aggregate.stdDevPopulation(qty),
    Aggregate.variance(qty),
    Aggregate.variancePopulation(qty),
    Aggregate.count,
    Aggregate.distinctCount(country),
    Aggregate.distinctCount(size),
    Aggregate.expression(
      'sum(qty * price) / sum(qty)',
      id: 'w',
      label: 'Weighted',
    ),
  ],
  filter: AndFilter([
    ValueFilter(region, ['Europe', 'Asia', null]),
    ValueFilter(year, [2024, 2025]),
    OrFilter([
      CompareFilter('qty', CompareOp.greaterOrEqual, 1),
      CompareFilter('date', CompareOp.less, DateTime.utc(2026, 1, 1)),
      CompareFilter('country', CompareOp.notEqual, 'x'),
      CompareFilter('country', CompareOp.greater, 'A'),
    ]),
    NotFilter(EmptyFilter('price', negated: true)),
    RangeFilter('date', DateTime.utc(2024, 1, 1), DateTime.utc(2025, 12, 31)),
    TextFilter('country', TextMatch.startsWith, 'G'),
    ExpressionFilter('qty is not empty or price > 60', label: 'has data'),
  ]),
);

void main() {
  const codec = CubeJson.standard;

  test('a rich spec survives JSON text', () {
    final json = viaText(codec.encodeSpec(richSpec)) as Map<String, Object?>;
    final back = codec.decodeSpec(json);
    expect(codec.encodeSpec(back), codec.encodeSpec(richSpec));
    // identities
    expect(
      back.rows.dimensions.map((d) => d.dimension),
      richSpec.rows.dimensions.map((d) => d.dimension),
    );
    expect(
      back.columns.dimensions.map((d) => d.dimension),
      richSpec.columns.dimensions.map((d) => d.dimension),
    );
    expect(back.aggregates, richSpec.aggregates);
    expect(back.rows.summaryPosition, SummaryPosition.start);
    expect(back.rows.subtotalPosition, SubtotalPosition.bottom);
    expect(back.columns.summaryPosition, SummaryPosition.hidden);
    // sorts
    final s0 = back.rows.dimensions[0].sort!;
    expect(
      (s0.by, s0.direction, s0.nulls),
      (SortBy.value, SortDirection.descending, NullPosition.last),
    );
    final s1 = back.rows.dimensions[1].sort!;
    expect(s1.aggregate, Aggregate.sum(qty));
    expect(s1.keyPath, const DimensionPath([DimensionValue(year, 2024)]));
    expect(back.rows.dimensions[2].sort, isNull);
    // labels and ids
    expect(back.rows.dimensions[1].dimension.explicitLabel, 'Land');
    expect(
      back.rows.dimensions[2].dimension,
      isA<ExpressionDimension>()
          .having((d) => d.id, 'id', 'size')
          .having((d) => d.label, 'label', 'Size'),
    );
    expect(
      (back.aggregates[1] as AverageAggregate).measure.explicitLabel,
      'Price',
    );
    expect(
      (back.aggregates[2] as MinAggregate).measure,
      isA<ExpressionMeasure>()
          .having((m) => m.id, 'id', 'net')
          .having((m) => m.label, 'label', 'Net'),
    );
    expect(
      back.aggregates.last,
      isA<ExpressionAggregate>()
          .having((a) => a.label, 'label', 'Weighted')
          .having((a) => a.id, 'id', 'w'),
    );
    // filter
    final and = back.filter as AndFilter;
    expect(and.filters.length, 7);
    expect((and.filters[0] as ValueFilter).values, {'Europe', 'Asia', null});
    expect((and.filters[1] as ValueFilter).values, {2024, 2025});
    final or = and.filters[2] as OrFilter;
    expect((or.filters[1] as CompareFilter).value, DateTime.utc(2026, 1, 1));
    expect((or.filters[3] as CompareFilter).value, 'A');
    expect(back.filter, richSpec.filter);
    expect(and.filters[3], NotFilter(EmptyFilter('price', negated: true)));
    expect((and.filters[4] as RangeFilter).high, DateTime.utc(2025, 12, 31));
    expect(and.filters[5], TextFilter('country', TextMatch.startsWith, 'G'));
    expect((and.filters[6] as ExpressionFilter).label, 'has data');
    expect(
      back.filter!.toExpressionSource(),
      richSpec.filter!.toExpressionSource(),
    );
  });

  test('the JSON shape is readable and stable', () {
    final json = codec.encodeSpec(
      CubeSpec(
        rows: CubeAxis.of([region]),
        aggregates: [Aggregate.sum(qty), Aggregate.count],
        filter: CompareFilter('date', CompareOp.less, DateTime.utc(2026, 1, 1)),
      ),
    );
    expect(json, {
      'rows': {
        'dimensions': [
          {
            'dimension': {'type': 'column', 'column': 'region'},
          },
        ],
        'summary': 'end',
        'subtotals': 'top',
      },
      'columns': {
        'dimensions': <Object?>[],
        'summary': 'end',
        'subtotals': 'top',
      },
      'aggregates': [
        {
          'type': 'sum',
          'measure': {'column': 'qty'},
        },
        {'type': 'count'},
      ],
      'filter': {
        'type': 'compare',
        'column': 'date',
        'op': 'less',
        'value': {'date': '2026-01-01T00:00:00.000Z'},
      },
    });
    expect(codec.encodeDimension(month), {
      'type': 'datePart',
      'column': 'date',
      'part': 'month',
      'label': 'Monat',
    });
    expect(codec.encodeAggregate(Aggregate.stdDevPopulation(net)), {
      'type': 'stdevp',
      'measure': {'expression': 'qty * price', 'id': 'net', 'label': 'Net'},
    });
    expect(codec.encodeMeasure(Measure.expression('qty * 2')), {
      'expression': 'qty * 2',
    });
  });

  test('expansion states are positional against their axis', () async {
    final f = await facts();
    final spec = CubeSpec(
      rows: CubeAxis.of([region, country]),
      columns: CubeAxis.of([year, month]),
      aggregates: [Aggregate.sum(qty)],
    );
    var cube = Cube(facts: f, spec: spec);
    cube = cube
        .toggleRow(const DimensionPath([DimensionValue(region, 'Europe')]))
        .toggleRow(const DimensionPath([DimensionValue(region, null)]))
        .toggleColumn(const DimensionPath([DimensionValue(year, 2024)]));
    final rows = codec.encodeExpansion(cube.rowExpansion, spec.rows);
    expect(rows, [
      <Object?>[],
      ['Europe'],
      [null],
    ]);
    final cols = viaText(
      codec.encodeExpansion(cube.columnExpansion, spec.columns),
    ) as List<Object?>;
    expect(cols, [
      <Object?>[],
      [2024],
    ]);
    final back = codec.decodeExpansion(
      viaText(rows) as List<Object?>,
      spec.rows,
    );
    expect(back.expanded, cube.rowExpansion.expanded);
    expect(
      codec.decodeExpansion(cols, spec.columns).expanded,
      cube.columnExpansion.expanded,
    );
    // a path that does not fit the axis is dropped on encode, rejected on decode
    final foreign = ExpansionState.of([
      const DimensionPath([DimensionValue(year, 2024)]),
    ]);
    expect(codec.encodeExpansion(foreign, spec.rows), [<Object?>[]]);
    expect(
      () => codec.decodeExpansion([
        <Object?>['a', 'b', 'c'],
      ], spec.rows),
      throwsFormatException,
    );
    // the restored cube has the same layout
    final restored = CubeConfig(
      spec: spec,
      rowExpansion: back,
      columnExpansion: codec.decodeExpansion(cols, spec.columns),
    ).toCube(f);
    expect(
      restored.layout.rows.entries.map((e) => e.path),
      cube.layout.rows.entries.map((e) => e.path),
    );
    expect(
      restored.layout.columns.entries.map((e) => e.path),
      cube.layout.columns.entries.map((e) => e.path),
    );
  });

  test('a config round-trips and rebuilds the same cube', () async {
    final f = await facts();
    final cube = Cube(
      facts: f,
      spec: richSpec,
    ).expandRowsToDepth(2).expandColumnsToDepth(1);
    // the facts' own schema lacks the excluded column
    expect(CubeConfig.of(cube).schema!['active'], isNull);
    final config = CubeConfig.of(cube, schema: declared);
    final text = jsonEncode(codec.encodeConfig(config));
    final back = codec.decodeConfig(jsonDecode(text) as Map<String, Object?>);
    expect(codec.encodeConfig(back), codec.encodeConfig(config));
    final restored = back.toCube(f);
    final a = cube.layout, b = restored.layout;
    expect(
      b.rows.entries.map((e) => e.path),
      a.rows.entries.map((e) => e.path),
    );
    expect(
      b.columns.entries.map((e) => e.path),
      a.columns.entries.map((e) => e.path),
    );
    for (var r = 0; r < a.rows.length; r++) {
      for (var c = 0; c < a.columns.length; c++) {
        expect(
          b.cellAt(r, c).aggregates,
          a.cellAt(r, c).aggregates,
          reason: '($r, $c)',
        );
      }
    }
    // the schema came along
    final schema = back.schema!;
    expect(schema['country']!.label, 'Country');
    expect(schema['date']!.format, 'yyyy-MM-dd');
    expect(schema['price']!.numberSyntax.decimalSeparator, ',');
    expect(
      schema['price']!.numberSyntax.thousandsSeparators,
      NumberSyntax.european.thousandsSeparators,
    );
    expect(schema['price']!.nullValues, {'', '?'});
    expect(schema['active']!.include, isFalse);
    expect(schema['qty']!.nullValues, ColumnSpec.defaultNullValues);
    expect(schema['qty']!.numberSyntax, NumberSyntax.standard);
    // re-importing with the restored schema gives the same facts
    final again = await loadFacts(
      ListDataSource(
        columns: ['region', 'country', 'date', 'qty', 'price', 'active'],
        rows: _rows,
        declaredSchema: schema,
      ),
    );
    expect(
      again.facts.columns.map((c) => c.name),
      f.columns.map((c) => c.name),
    );
    expect(again.facts.column('country').label, 'Country');
    expect(codec.encodeConfig(config)['version'], 1);
  });

  test('schema encoding drops the parser and defaults', () {
    final spec = ColumnSpec(name: 'x', type: ColumnType.text, parser: (v) => v);
    final json = codec.encodeColumnSpec(spec);
    expect(json, {'name': 'x', 'type': 'text'});
    expect(codec.decodeColumnSpec(json).parser, isNull);
  });

  test('custom members need adapters', () {
    final custom = MappedDimension(id: 'm', sourceColumn: 'qty', map: (v) => v);
    expect(() => codec.encodeDimension(custom), throwsUnsupportedError);
    expect(
      () => codec.encodeFilter(PredicateFilter((_, _) => true)),
      throwsUnsupportedError,
    );
    expect(
      () => codec.encodeAggregate(const _Range(qty)),
      throwsUnsupportedError,
    );
    expect(() => codec.encodeValue(const Duration()), throwsUnsupportedError);
    const withAdapters = CubeJson(aggregates: [_RangeAdapter()]);
    final json = withAdapters.encodeAggregate(const _Range(price));
    expect(json, {
      'type': 'range',
      'measure': {'column': 'price', 'label': 'Price'},
    });
    expect(
      withAdapters.decodeAggregate(viaText(json) as Map<String, Object?>),
      const _Range(price),
    );
    expect(() => codec.decodeAggregate(json), throwsFormatException);
    // adapters see the whole spec
    final spec = CubeSpec(aggregates: [const _Range(qty), Aggregate.count]);
    expect(
      withAdapters.decodeSpec(withAdapters.encodeSpec(spec)).aggregates,
      spec.aggregates,
    );
  });

  test('functions are passed to decoded expressions', () async {
    final f = await facts();
    final fns = FunctionRegistry.standard().withFunction(
      ExpressionFunction(
        'twice',
        parameters: [ExprType.number],
        returns: ExprType.number,
        implementation: (a) => a[0] == null ? null : (a[0] as double) * 2,
      ),
    );
    final json = codec.encodeSpec(
      CubeSpec(
        rows: CubeAxis.of([ExpressionDimension('twice(qty) > 4')]),
        aggregates: [
          Aggregate.sum(Measure.expression('twice(qty)', functions: fns)),
          Aggregate.expression('sum(twice(price))'),
        ],
        filter: ExpressionFilter('twice(qty) > 0'),
      ),
    );
    final plain = codec.decodeSpec(json);
    expect(
      () => Cube(facts: f, spec: plain).layout,
      throwsA(isA<ExpressionError>()),
    );
    final withFns = CubeJson(functions: fns).decodeSpec(json);
    final cube = Cube(facts: f, spec: withFns);
    expect(cube.layout.rows.length, 3);
    final total = cube.layout.rows.entries.indexWhere((e) => e.path.isRoot);
    expect(cube.layout.cellAt(total, 0).aggregate(withFns.aggregates[0]), 22.0);
    // the filter drops the row without a quantity (price 70)
    expect(
      cube.layout.cellAt(total, 0).aggregate(withFns.aggregates[1]),
      160.0,
    );
  });

  test('malformed input is a FormatException', () {
    Matcher fails = throwsFormatException;
    expect(() => codec.decodeSpec({}), fails);
    expect(
      () => codec.decodeSpec({'rows': 1, 'columns': {}, 'aggregates': []}),
      fails,
    );
    expect(() => codec.decodeDimension({'type': 'nope'}), fails);
    expect(() => codec.decodeDimension({'type': 'column'}), fails);
    expect(
      () => codec.decodeDimension({
        'type': 'datePart',
        'column': 'd',
        'part': 'century',
      }),
      fails,
    );
    expect(() => codec.decodeAggregate({'type': 'sum'}), fails);
    expect(() => codec.decodeAggregate({'type': 'sum', 'measure': {}}), fails);
    expect(
      () => codec.decodeFilter({
        'type': 'compare',
        'column': 'x',
        'op': 'like',
        'value': 1,
      }),
      fails,
    );
    expect(
      () => codec.decodeFilter({
        'type': 'compare',
        'column': 'x',
        'op': 'equal',
        'value': null,
      }),
      fails,
    );
    expect(
      () => codec.decodeFilter({
        'type': 'and',
        'filters': [1],
      }),
      fails,
    );
    expect(() => codec.decodeValue({'date': 'yesterday'}), fails);
    expect(() => codec.decodeValue([1]), fails);
    expect(() => codec.decodeConfig({'version': 99}), fails);
    expect(() => codec.decodeConfig({'spec': {}}), fails);
    expect(
      () => codec.decodeAxis({'dimensions': [], 'summary': 'middle'}),
      fails,
    );
    expect(() => codec.decodeColumnSpec({'name': 'x', 'type': 'blob'}), fails);
    // a duplicate dimension is the spec's own error
    expect(
      () => codec.decodeSpec({
        'rows': {
          'dimensions': [
            {
              'dimension': {'type': 'column', 'column': 'a'},
            },
            {
              'dimension': {'type': 'column', 'column': 'a'},
            },
          ],
        },
        'columns': {'dimensions': []},
        'aggregates': [],
      }),
      throwsArgumentError,
    );
  });

  test('values', () {
    expect(codec.encodeValue(null), isNull);
    expect(codec.encodeValue(3), 3);
    expect(codec.encodeValue(2.5), 2.5);
    expect(codec.encodeValue('a'), 'a');
    expect(codec.encodeValue(false), false);
    expect(codec.encodeValue(DateTime(2024, 5, 6, 12)), {
      'date': DateTime(2024, 5, 6, 12).toUtc().toIso8601String(),
    });
    expect(
      codec.decodeValue({'date': '2024-05-06T00:00:00.000Z'}),
      DateTime.utc(2024, 5, 6),
    );
    expect(
      codec.decodeValue(viaText(codec.encodeValue(DateTime.utc(2024, 5, 6)))),
      DateTime.utc(2024, 5, 6),
    );
    expect(codec.decodeValue(7), 7);
    expect(codec.decodeValue(null), isNull);
  });
}

/// max − min of a measure, with an adapter.
final class _Range extends DerivedAggregate<double> {
  const _Range(this.measure);
  final Measure measure;

  @override
  String get id => 'range(${measure.id})';

  @override
  String get label => 'range of ${measure.label}';

  @override
  List<Aggregate> get dependencies => [
    Aggregate.min(measure),
    Aggregate.max(measure),
  ];

  @override
  double? compute(Object? Function(Aggregate) resultOf) {
    final lo = resultOf(Aggregate.min(measure)) as double?;
    final hi = resultOf(Aggregate.max(measure)) as double?;
    return lo == null || hi == null ? null : hi - lo;
  }
}

final class _RangeAdapter extends JsonAdapter<Aggregate> {
  const _RangeAdapter();

  @override
  String get type => 'range';

  @override
  Map<String, Object?>? encode(Aggregate value, CubeJson codec) =>
      value is _Range ? {'measure': codec.encodeMeasure(value.measure)} : null;

  @override
  Aggregate decode(Map<String, Object?> json, CubeJson codec) =>
      _Range(codec.decodeMeasure(json['measure'] as Map<String, Object?>));
}
