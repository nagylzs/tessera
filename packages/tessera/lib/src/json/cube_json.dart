import '../cube/aggregate.dart';
import '../cube/cube.dart';
import '../cube/cube_spec.dart';
import '../cube/dimension_path.dart';
import '../cube/expansion_state.dart';
import '../cube/filter.dart';
import '../cube/layout_aggregate.dart';
import '../expr/functions.dart';
import '../facts/dimension.dart';
import '../facts/fact_table.dart';
import '../facts/measure.dart';
import '../schema/column_spec.dart';
import '../schema/column_type.dart';
import '../schema/schema.dart';
import '../schema/value_parsing.dart';

/// Everything that rebuilds a cube on the same data: the spec, both
/// expansion states and the schema the facts were imported with. What an
/// application saves ([CubeJson.encodeConfig]) and restores
/// ([CubeJson.decodeConfig], then [toCube]).
final class CubeConfig {
  CubeConfig({
    required this.spec,
    ExpansionState? rowExpansion,
    ExpansionState? columnExpansion,
    this.schema,
  }) : rowExpansion = rowExpansion ?? ExpansionState.initial(),
       columnExpansion = columnExpansion ?? ExpansionState.initial();

  /// The configuration of [cube]. [schema] defaults to the schema of the
  /// cube's facts, which holds the imported columns only (with the types
  /// the import settled on); an application that lets the user edit a
  /// schema, excluded columns included, passes that one instead.
  CubeConfig.of(Cube cube, {Schema? schema})
    : this(
        spec: cube.spec,
        rowExpansion: cube.rowExpansion,
        columnExpansion: cube.columnExpansion,
        schema: schema ?? cube.facts.schema,
      );

  final CubeSpec spec;
  final ExpansionState rowExpansion;
  final ExpansionState columnExpansion;

  /// The schema (column types, labels, exclusions, formats) the facts were
  /// imported with, so an application can re-import the same source the
  /// same way; `null` when not recorded.
  final Schema? schema;

  /// A cube over [facts] with this spec and expansion.
  Cube toCube(FactTable facts) => Cube(
    facts: facts,
    spec: spec,
    rowExpansion: rowExpansion,
    columnExpansion: columnExpansion,
  );
}

/// Encodes and decodes one kind of application-defined value — a custom
/// [Aggregate], [Dimension] or [FactFilter] — for [CubeJson].
///
/// [encode] returns the JSON object for a value this adapter handles
/// (without the `type` key, which the codec adds) or `null` for any other
/// value; [decode] rebuilds the value from that object.
abstract class JsonAdapter<T extends Object> {
  const JsonAdapter();

  /// The value of the `type` key that marks this adapter's objects. Must
  /// not clash with the built-in types.
  String get type;

  Map<String, Object?>? encode(T value, CubeJson codec);

  T decode(Map<String, Object?> json, CubeJson codec);
}

/// JSON form of a pivot configuration: [CubeConfig], [CubeSpec],
/// [ExpansionState], [Schema] and every value they contain.
///
/// The output is plain `Map` / `List` / `String` / `num` / `bool` / `null`
/// data for `dart:convert`. Dates are encoded as `{"date": "<ISO 8601>"}`
/// so they survive the round trip. Dimensions, measures, aggregates and
/// filters are objects with a `type` (or, for measures, a `column` or
/// `expression`) key; expansion paths are positional lists of values
/// against their axis. Custom [Aggregate]s, [MappedDimension]s and
/// [PredicateFilter]s need a [JsonAdapter]; without one, encoding them
/// throws [UnsupportedError]. A [ColumnSpec.parser] is not stored.
/// Decoding malformed input throws [FormatException].
///
/// [functions] is handed to every expression-based member that is decoded
/// (filters, measures, dimensions, cell formulas), so application
/// functions resolve after a restore.
final class CubeJson {
  const CubeJson({
    this.aggregates = const [],
    this.dimensions = const [],
    this.filters = const [],
    this.functions,
  });

  /// The codec with no adapters and the built-in functions.
  static const standard = CubeJson();

  final List<JsonAdapter<Aggregate>> aggregates;
  final List<JsonAdapter<Dimension>> dimensions;
  final List<JsonAdapter<FactFilter>> filters;
  final FunctionRegistry? functions;

  /// The format version written into a config, for future migrations.
  static const version = 1;

  // ---------------------------------------------------------------- config

  Map<String, Object?> encodeConfig(CubeConfig config) => {
    'version': version,
    'spec': encodeSpec(config.spec),
    'rowExpansion': encodeExpansion(config.rowExpansion, config.spec.rows),
    'columnExpansion': encodeExpansion(
      config.columnExpansion,
      config.spec.columns,
    ),
    if (config.schema != null) 'schema': encodeSchema(config.schema!),
  };

  CubeConfig decodeConfig(Map<String, Object?> json) {
    final v = json['version'];
    if (v is! int || v < 1 || v > version) {
      throw FormatException('config: unsupported version $v');
    }
    final spec = decodeSpec(_map(json, 'spec'));
    return CubeConfig(
      spec: spec,
      rowExpansion: json['rowExpansion'] == null
          ? null
          : decodeExpansion(_list(json, 'rowExpansion'), spec.rows),
      columnExpansion: json['columnExpansion'] == null
          ? null
          : decodeExpansion(_list(json, 'columnExpansion'), spec.columns),
      schema: json['schema'] == null
          ? null
          : decodeSchema(_map(json, 'schema')),
    );
  }

  // ------------------------------------------------------------------ spec

  Map<String, Object?> encodeSpec(CubeSpec spec) => {
    'rows': encodeAxis(spec.rows),
    'columns': encodeAxis(spec.columns),
    'aggregates': [for (final a in spec.aggregates) encodeAggregate(a)],
    if (spec.filter != null) 'filter': encodeFilter(spec.filter!),
  };

  CubeSpec decodeSpec(Map<String, Object?> json) => CubeSpec(
    rows: decodeAxis(_map(json, 'rows')),
    columns: decodeAxis(_map(json, 'columns')),
    aggregates: [
      for (final a in _list(json, 'aggregates')) decodeAggregate(_asMap(a)),
    ],
    filter: json['filter'] == null ? null : decodeFilter(_map(json, 'filter')),
  );

  Map<String, Object?> encodeAxis(CubeAxis axis) => {
    'dimensions': [
      for (final d in axis.dimensions)
        {
          'dimension': encodeDimension(d.dimension),
          if (d.sort != null) 'sort': encodeSort(d.sort!),
        },
    ],
    'summary': axis.summaryPosition.name,
    'subtotals': axis.subtotalPosition.name,
  };

  CubeAxis decodeAxis(Map<String, Object?> json) => CubeAxis(
    dimensions: [
      for (final d in _list(json, 'dimensions'))
        AxisDimension(
          decodeDimension(_map(_asMap(d), 'dimension')),
          sort: _asMap(d)['sort'] == null
              ? null
              : decodeSort(_map(_asMap(d), 'sort')),
        ),
    ],
    summaryPosition: _enum(
      json,
      'summary',
      SummaryPosition.values,
      SummaryPosition.end,
    ),
    subtotalPosition: _enum(
      json,
      'subtotals',
      SubtotalPosition.values,
      SubtotalPosition.top,
    ),
  );

  Map<String, Object?> encodeSort(AxisSort sort) => {
    'by': sort.by.name,
    if (sort.aggregate != null) 'aggregate': encodeAggregate(sort.aggregate!),
    if (sort.keyPath != null) 'keyPath': encodePath(sort.keyPath!),
    'direction': sort.direction.name,
    'nulls': sort.nulls.name,
  };

  AxisSort decodeSort(Map<String, Object?> json) => AxisSort(
    by: _enum(json, 'by', SortBy.values, SortBy.value),
    aggregate: json['aggregate'] == null
        ? null
        : decodeAggregate(_map(json, 'aggregate')),
    keyPath: json['keyPath'] == null
        ? null
        : decodePath(_list(json, 'keyPath')),
    direction: _enum(
      json,
      'direction',
      SortDirection.values,
      SortDirection.ascending,
    ),
    nulls: _enum(json, 'nulls', NullPosition.values, NullPosition.first),
  );

  // ------------------------------------------------------------ dimensions

  Map<String, Object?> encodeDimension(Dimension dimension) {
    switch (dimension) {
      case ColumnDimension(:final sourceColumn, :final explicitLabel):
        return {
          'type': 'column',
          'column': sourceColumn,
          'label': ?explicitLabel,
        };
      case DatePartDimension(
        :final sourceColumn,
        :final part,
        :final explicitLabel,
      ):
        return {
          'type': 'datePart',
          'column': sourceColumn,
          'part': part.name,
          'label': ?explicitLabel,
        };
      case ExpressionDimension(:final source, :final id, :final explicitLabel):
        return {
          'type': 'expression',
          'source': source,
          if (id != source) 'id': id,
          'label': ?explicitLabel,
        };
      case MappedDimension():
        return _custom(dimensions, dimension, 'dimension');
    }
  }

  Dimension decodeDimension(Map<String, Object?> json) {
    final type = _string(json, 'type');
    final label = _optString(json, 'label');
    switch (type) {
      case 'column':
        return ColumnDimension(_string(json, 'column'), label: label);
      case 'datePart':
        return DatePartDimension(
          _string(json, 'column'),
          _enum(json, 'part', DatePart.values, null),
          label: label,
        );
      case 'expression':
        return ExpressionDimension(
          _string(json, 'source'),
          id: _optString(json, 'id'),
          label: label,
          functions: functions,
        );
    }
    return _decodeCustom(dimensions, type, json, 'dimension');
  }

  // -------------------------------------------------------------- measures

  Map<String, Object?> encodeMeasure(Measure measure) => switch (measure) {
    ColumnMeasure(:final column, :final explicitLabel) => {
      'column': column,
      'label': ?explicitLabel,
    },
    ExpressionMeasure(:final source, :final id, :final explicitLabel) => {
      'expression': source,
      if (id != source) 'id': id,
      'label': ?explicitLabel,
    },
  };

  Measure decodeMeasure(Map<String, Object?> json) {
    final label = _optString(json, 'label');
    if (json.containsKey('expression')) {
      return Measure.expression(
        _string(json, 'expression'),
        id: _optString(json, 'id'),
        label: label,
        functions: functions,
      );
    }
    return Measure(_string(json, 'column'), label: label);
  }

  // ------------------------------------------------------------ aggregates

  static const _measureTypes = {
    SumAggregate: 'sum',
    AverageAggregate: 'avg',
    MinAggregate: 'min',
    MaxAggregate: 'max',
    CountNonNullAggregate: 'countValues',
    StdDevAggregate: 'stdev',
    StdDevPopulationAggregate: 'stdevp',
    VarianceAggregate: 'var',
    VariancePopulationAggregate: 'varp',
  };

  Map<String, Object?> encodeAggregate(Aggregate aggregate) {
    switch (aggregate) {
      case CountAggregate():
        return const {'type': 'count'};
      case DistinctCountAggregate(:final dimension):
        return {'type': 'distinct', 'dimension': encodeDimension(dimension)};
      case ExpressionAggregate(:final source, :final id, :final explicitLabel):
        return {
          'type': 'expression',
          'source': source,
          if (id != source) 'id': id,
          'label': ?explicitLabel,
        };
      case PercentOfTotalAggregate(:final base, :final of):
        return {
          'type': 'percentOf',
          'base': encodeAggregate(base),
          'of': of.name,
        };
      case DifferenceFromAggregate(:final base, :final axis, :final item):
        return {
          'type': 'differenceFrom',
          'base': encodeAggregate(base),
          'axis': axis.name,
          'item': _encodeItem(item),
        };
      case PercentDifferenceFromAggregate(
        :final base,
        :final axis,
        :final item,
      ):
        return {
          'type': 'percentDifferenceFrom',
          'base': encodeAggregate(base),
          'axis': axis.name,
          'item': _encodeItem(item),
        };
      case RunningTotalAggregate(:final base, :final axis):
        return {
          'type': 'runningTotal',
          'base': encodeAggregate(base),
          'axis': axis.name,
        };
      case RankAggregate(:final base, :final axis, :final ascending):
        return {
          'type': 'rank',
          'base': encodeAggregate(base),
          'axis': axis.name,
          if (ascending) 'ascending': true,
        };
      case MeasureAggregate(:final measure):
        final type = _measureTypes[aggregate.runtimeType];
        if (type != null) {
          return {'type': type, 'measure': encodeMeasure(measure)};
        }
    }
    return _custom(aggregates, aggregate, 'aggregate');
  }

  Object? _encodeItem(BaseItem item) => switch (item) {
    PreviousItem() => 'previous',
    NextItem() => 'next',
    ValueItem(:final value) => {'value': encodeValue(value)},
  };

  BaseItem _decodeItem(Object? json) {
    if (json == 'previous') return BaseItem.previous;
    if (json == 'next') return BaseItem.next;
    if (json is Map && json.containsKey('value')) {
      return BaseItem.value(decodeValue(json['value']));
    }
    throw FormatException(
      '"item": expected previous, next or {value}, got $json',
    );
  }

  Aggregate decodeAggregate(Map<String, Object?> json) {
    final type = _string(json, 'type');
    switch (type) {
      case 'count':
        return Aggregate.count;
      case 'distinct':
        return Aggregate.distinctCount(
          decodeDimension(_map(json, 'dimension')),
        );
      case 'expression':
        return Aggregate.expression(
          _string(json, 'source'),
          id: _optString(json, 'id'),
          label: _optString(json, 'label'),
          functions: functions,
        );
      case 'percentOf':
        return Aggregate.percentOf(
          decodeAggregate(_map(json, 'base')),
          _enum(json, 'of', TotalOf.values, null),
        );
      case 'differenceFrom':
        return Aggregate.differenceFrom(
          decodeAggregate(_map(json, 'base')),
          axis: _enum(json, 'axis', AxisSide.values, null),
          item: _decodeItem(json['item']),
        );
      case 'percentDifferenceFrom':
        return Aggregate.percentDifferenceFrom(
          decodeAggregate(_map(json, 'base')),
          axis: _enum(json, 'axis', AxisSide.values, null),
          item: _decodeItem(json['item']),
        );
      case 'runningTotal':
        return Aggregate.runningTotal(
          decodeAggregate(_map(json, 'base')),
          axis: _enum(json, 'axis', AxisSide.values, null),
        );
      case 'rank':
        return Aggregate.rank(
          decodeAggregate(_map(json, 'base')),
          axis: _enum(json, 'axis', AxisSide.values, null),
          ascending: json['ascending'] == true,
        );
    }
    if (_measureTypes.containsValue(type)) {
      final m = decodeMeasure(_map(json, 'measure'));
      return switch (type) {
        'sum' => Aggregate.sum(m),
        'avg' => Aggregate.average(m),
        'min' => Aggregate.min(m),
        'max' => Aggregate.max(m),
        'countValues' => Aggregate.countNonNull(m),
        'stdev' => Aggregate.stdDev(m),
        'stdevp' => Aggregate.stdDevPopulation(m),
        'var' => Aggregate.variance(m),
        _ => Aggregate.variancePopulation(m),
      };
    }
    return _decodeCustom(aggregates, type, json, 'aggregate');
  }

  // --------------------------------------------------------------- filters

  Map<String, Object?> encodeFilter(FactFilter filter) {
    switch (filter) {
      case ValueFilter(:final dimension, :final values):
        return {
          'type': 'value',
          'dimension': encodeDimension(dimension),
          'values': [for (final v in values) encodeValue(v)],
        };
      case ExpressionFilter(:final source, :final label):
        return {'type': 'expression', 'source': source, 'label': ?label};
      case CompareFilter(:final column, :final op, :final value):
        return {
          'type': 'compare',
          'column': column,
          'op': op.name,
          'value': encodeValue(value),
        };
      case RangeFilter(:final column, :final low, :final high):
        return {
          'type': 'range',
          'column': column,
          'low': encodeValue(low),
          'high': encodeValue(high),
        };
      case TextFilter(:final column, :final match, :final text):
        return {
          'type': 'text',
          'column': column,
          'match': match.name,
          'text': text,
        };
      case EmptyFilter(:final column, :final negated):
        return {'type': 'empty', 'column': column, 'negated': negated};
      case AndFilter(:final filters):
        return {
          'type': 'and',
          'filters': [for (final f in filters) encodeFilter(f)],
        };
      case OrFilter(:final filters):
        return {
          'type': 'or',
          'filters': [for (final f in filters) encodeFilter(f)],
        };
      case NotFilter(:final filter):
        return {'type': 'not', 'filter': encodeFilter(filter)};
      case PredicateFilter():
        return _custom(filters, filter, 'filter');
    }
  }

  FactFilter decodeFilter(Map<String, Object?> json) {
    final type = _string(json, 'type');
    switch (type) {
      case 'value':
        return ValueFilter(decodeDimension(_map(json, 'dimension')), [
          for (final v in _list(json, 'values')) decodeValue(v),
        ]);
      case 'expression':
        return ExpressionFilter(
          _string(json, 'source'),
          label: _optString(json, 'label'),
          functions: functions,
        );
      case 'compare':
        return CompareFilter(
          _string(json, 'column'),
          _enum(json, 'op', CompareOp.values, null),
          _nonNull(decodeValue(json['value']), 'value'),
        );
      case 'range':
        return RangeFilter(
          _string(json, 'column'),
          _nonNull(decodeValue(json['low']), 'low'),
          _nonNull(decodeValue(json['high']), 'high'),
        );
      case 'text':
        return TextFilter(
          _string(json, 'column'),
          _enum(json, 'match', TextMatch.values, null),
          _string(json, 'text'),
        );
      case 'empty':
        return EmptyFilter(
          _string(json, 'column'),
          negated: json['negated'] == true,
        );
      case 'and':
        return AndFilter([
          for (final f in _list(json, 'filters')) decodeFilter(_asMap(f)),
        ]);
      case 'or':
        return OrFilter([
          for (final f in _list(json, 'filters')) decodeFilter(_asMap(f)),
        ]);
      case 'not':
        return NotFilter(decodeFilter(_map(json, 'filter')));
    }
    return _decodeCustom(filters, type, json, 'filter');
  }

  // ------------------------------------------------------- paths, expansion

  /// A path as a list of `{"dimension": …, "value": …}` entries: complete
  /// on its own (used for sort keys).
  List<Object?> encodePath(DimensionPath path) => [
    for (final e in path.entries)
      {
        'dimension': encodeDimension(e.dimension),
        'value': encodeValue(e.value),
      },
  ];

  DimensionPath decodePath(List<Object?> json) => DimensionPath([
    for (final e in json)
      DimensionValue(
        decodeDimension(_map(_asMap(e), 'dimension')),
        decodeValue(_asMap(e)['value']),
      ),
  ]);

  /// The expanded paths of [state] as lists of values, positional against
  /// the dimensions of [axis] (`[]` is the root). Paths that do not fit the
  /// axis are dropped.
  List<Object?> encodeExpansion(ExpansionState state, CubeAxis axis) {
    final dims = [for (final d in axis.dimensions) d.dimension];
    final out = <List<Object?>>[];
    for (final p in state.expanded) {
      if (p.length > dims.length) continue;
      var fits = true;
      for (var i = 0; i < p.length; i++) {
        if (p.entries[i].dimension != dims[i]) {
          fits = false;
          break;
        }
      }
      if (fits) out.add([for (final e in p.entries) encodeValue(e.value)]);
    }
    // Shortest first, then by text, so the output is deterministic.
    out.sort((a, b) {
      final byLength = a.length - b.length;
      return byLength != 0 ? byLength : a.toString().compareTo(b.toString());
    });
    return out;
  }

  ExpansionState decodeExpansion(List<Object?> json, CubeAxis axis) {
    final dims = [for (final d in axis.dimensions) d.dimension];
    return ExpansionState.of([
      for (final p in json)
        DimensionPath([
          for (final (i, v) in _asList(p).indexed)
            if (i < dims.length)
              DimensionValue(dims[i], decodeValue(v))
            else
              throw FormatException(
                'expansion: a path is longer than the axis',
              ),
        ]),
    ]);
  }

  // ---------------------------------------------------------------- schema

  Map<String, Object?> encodeSchema(Schema schema) => {
    'columns': [for (final c in schema.columns) encodeColumnSpec(c)],
  };

  Schema decodeSchema(Map<String, Object?> json) => Schema([
    for (final c in _list(json, 'columns')) decodeColumnSpec(_asMap(c)),
  ]);

  /// Everything but [ColumnSpec.parser], which is a Dart function.
  Map<String, Object?> encodeColumnSpec(ColumnSpec spec) => {
    'name': spec.name,
    'type': spec.type.name,
    'label': ?spec.label,
    if (!spec.include) 'include': false,
    'format': ?spec.format,
    if (spec.numberSyntax != NumberSyntax.standard)
      'numberSyntax': {
        'decimal': spec.numberSyntax.decimalSeparator,
        'thousands': spec.numberSyntax.thousandsSeparators.toList(),
      },
    if (spec.nullValues != ColumnSpec.defaultNullValues)
      'nullValues': spec.nullValues.toList(),
  };

  ColumnSpec decodeColumnSpec(Map<String, Object?> json) {
    final syntax = json['numberSyntax'];
    final nullValues = json['nullValues'];
    return ColumnSpec(
      name: _string(json, 'name'),
      type: _enum(json, 'type', ColumnType.values, null),
      label: _optString(json, 'label'),
      include: json['include'] != false,
      format: _optString(json, 'format'),
      numberSyntax: syntax == null
          ? NumberSyntax.standard
          : NumberSyntax(
              decimalSeparator: _string(_asMap(syntax), 'decimal'),
              thousandsSeparators: {
                for (final s in _list(_asMap(syntax), 'thousands')) s as String,
              },
            ),
      nullValues: nullValues == null
          ? ColumnSpec.defaultNullValues
          : {for (final s in _asList(nullValues)) s as String},
    );
  }

  // ---------------------------------------------------------------- values

  /// A dimension or filter value: numbers, text, booleans and `null` as
  /// they are, a [DateTime] as `{"date": "<ISO 8601, UTC>"}`.
  Object? encodeValue(Object? value) => switch (value) {
    null || num() || String() || bool() => value,
    DateTime d => {'date': (d.isUtc ? d : d.toUtc()).toIso8601String()},
    _ => throw UnsupportedError(
      'cannot encode a ${value.runtimeType} value ($value)',
    ),
  };

  Object? decodeValue(Object? json) {
    if (json is Map && json.length == 1 && json['date'] is String) {
      final d = DateTime.tryParse(json['date'] as String);
      if (d == null) throw FormatException('invalid date "${json['date']}"');
      return d.toUtc();
    }
    if (json == null || json is num || json is String || json is bool) {
      return json;
    }
    throw FormatException('unexpected value $json');
  }

  // --------------------------------------------------------------- helpers

  Map<String, Object?> _custom<T extends Object>(
    List<JsonAdapter<T>> adapters,
    T value,
    String what,
  ) {
    for (final a in adapters) {
      final json = a.encode(value, this);
      if (json != null) return {'type': a.type, ...json};
    }
    throw UnsupportedError(
      'no JsonAdapter encodes the $what ${value.runtimeType} ($value)',
    );
  }

  T _decodeCustom<T extends Object>(
    List<JsonAdapter<T>> adapters,
    String type,
    Map<String, Object?> json,
    String what,
  ) {
    for (final a in adapters) {
      if (a.type == type) return a.decode(json, this);
    }
    throw FormatException('unknown $what type "$type"');
  }

  static Map<String, Object?> _asMap(Object? v) {
    if (v is Map) return v.cast<String, Object?>();
    throw FormatException('expected an object, got $v');
  }

  static List<Object?> _asList(Object? v) {
    if (v is List) return v;
    throw FormatException('expected a list, got $v');
  }

  static Map<String, Object?> _map(Map<String, Object?> json, String key) {
    final v = json[key];
    if (v is Map) return v.cast<String, Object?>();
    throw FormatException('"$key": expected an object, got $v');
  }

  static List<Object?> _list(Map<String, Object?> json, String key) {
    final v = json[key];
    if (v is List) return v;
    throw FormatException('"$key": expected a list, got $v');
  }

  static String _string(Map<String, Object?> json, String key) {
    final v = json[key];
    if (v is String) return v;
    throw FormatException('"$key": expected a string, got $v');
  }

  static String? _optString(Map<String, Object?> json, String key) {
    final v = json[key];
    if (v == null || v is String) return v as String?;
    throw FormatException('"$key": expected a string, got $v');
  }

  static T _nonNull<T extends Object>(Object? v, String key) {
    if (v is T) return v;
    throw FormatException('"$key": expected a value, got $v');
  }

  /// The enum named by [key]; [fallback] when the key is absent (`null`
  /// fallback = required).
  static E _enum<E extends Enum>(
    Map<String, Object?> json,
    String key,
    List<E> values,
    E? fallback,
  ) {
    final v = json[key];
    if (v == null && fallback != null) return fallback;
    for (final e in values) {
      if (e.name == v) return e;
    }
    throw FormatException('"$key": unknown value $v');
  }
}
