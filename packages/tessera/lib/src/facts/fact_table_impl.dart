import 'dart:typed_data';

import '../expr/checker.dart';
import '../expr/expr_type.dart';
import '../schema/column_spec.dart';
import '../schema/column_type.dart';
import '../schema/schema.dart';
import 'dimension.dart';
import 'fact_table.dart';
import 'measure.dart';

// Internal columnar storage behind [FactTable]. Not exported.
//
// Numbers and dates live in Float64List (NaN = null; integers are exact up to
// 2^53, dates are milliseconds since epoch, UTC). Text is dictionary encoded
// (Int32List of codes, -1 = null). Booleans are a Uint8List (0/1, 2 = null).

/// Growable Float64List.
final class DoubleBuffer {
  Float64List _data = Float64List(64);
  int length = 0;

  void add(double v) {
    if (length == _data.length) {
      _data = Float64List(length * 2)..setRange(0, length, _data);
    }
    _data[length++] = v;
  }

  double operator [](int i) => _data[i];

  Float64List build() => Float64List.sublistView(_data, 0, length);
}

/// Growable Int32List.
final class IntBuffer {
  Int32List _data = Int32List(64);
  int length = 0;

  void add(int v) {
    if (length == _data.length) {
      _data = Int32List(length * 2)..setRange(0, length, _data);
    }
    _data[length++] = v;
  }

  int operator [](int i) => _data[i];

  Int32List build() => Int32List.sublistView(_data, 0, length);
}

/// Growable Uint8List.
final class ByteBuffer {
  Uint8List _data = Uint8List(64);
  int length = 0;

  void add(int v) {
    if (length == _data.length) {
      _data = Uint8List(length * 2)..setRange(0, length, _data);
    }
    _data[length++] = v;
  }

  int operator [](int i) => _data[i];

  Uint8List build() => Uint8List.sublistView(_data, 0, length);
}

/// Accumulates one column's values during import and can be widened.
abstract base class ColumnBuilder {
  ColumnBuilder(this.name);

  final String name;

  ColumnType get type;

  int get length;

  /// [value] must already be of the builder's type (or `null`).
  void add(Object? value);

  Object? valueAt(int row);

  /// Returns a builder of [target] holding the same rows, converted.
  ColumnBuilder widenTo(ColumnType target) {
    assert(type.canWidenTo(target));
    if (target == type) return this;
    final next = ColumnBuilder.create(name, target);
    for (var i = 0; i < length; i++) {
      next.add(coerceForWidening(valueAt(i), target));
    }
    return next;
  }

  /// Converts an already-typed value to a wider type.
  static Object? coerceForWidening(Object? value, ColumnType target) {
    if (value == null) return null;
    return switch (target) {
      ColumnType.text => stringify(value),
      ColumnType.number => (value as num).toDouble(),
      ColumnType.dateTime => value as DateTime,
      _ => value,
    };
  }

  /// Canonical text form used when a typed value lands in a text column.
  static String stringify(Object value) => switch (value) {
    String s => s,
    DateTime d =>
      d.hour == 0 && d.minute == 0 && d.second == 0 && d.millisecond == 0
          ? d.toIso8601String().substring(0, 10)
          : d.toIso8601String(),
    double d =>
      d == d.truncateToDouble() && d.abs() < 1e15
          ? d.toInt().toString()
          : d.toString(),
    _ => value.toString(),
  };

  FactColumnImpl build(String label);

  static ColumnBuilder create(String name, ColumnType type) => switch (type) {
    ColumnType.text => TextColumnBuilder(name),
    ColumnType.integer || ColumnType.number => NumberColumnBuilder(name, type),
    ColumnType.boolean => BoolColumnBuilder(name),
    ColumnType.date || ColumnType.dateTime => DateColumnBuilder(name, type),
  };
}

final class NumberColumnBuilder extends ColumnBuilder {
  NumberColumnBuilder(super.name, this.type);

  @override
  ColumnType type;

  final _data = DoubleBuffer();

  @override
  int get length => _data.length;

  @override
  void add(Object? value) =>
      _data.add(value == null ? double.nan : (value as num).toDouble());

  @override
  Object? valueAt(int row) {
    final v = _data[row];
    if (v.isNaN) return null;
    return type == ColumnType.integer ? v.toInt() : v;
  }

  @override
  ColumnBuilder widenTo(ColumnType target) {
    if (target == ColumnType.number) {
      type = ColumnType.number; // same storage
      return this;
    }
    return super.widenTo(target);
  }

  @override
  FactColumnImpl build(String label) =>
      NumberColumn(name, label, type, _data.build());
}

final class DateColumnBuilder extends ColumnBuilder {
  DateColumnBuilder(super.name, this.type);

  @override
  ColumnType type;

  final _data = DoubleBuffer();

  @override
  int get length => _data.length;

  @override
  void add(Object? value) => _data.add(
    value == null
        ? double.nan
        : (value as DateTime).toUtc().millisecondsSinceEpoch.toDouble(),
  );

  @override
  Object? valueAt(int row) {
    final v = _data[row];
    return v.isNaN
        ? null
        : DateTime.fromMillisecondsSinceEpoch(v.toInt(), isUtc: true);
  }

  @override
  ColumnBuilder widenTo(ColumnType target) {
    if (target == ColumnType.dateTime) {
      type = ColumnType.dateTime;
      return this;
    }
    return super.widenTo(target);
  }

  @override
  FactColumnImpl build(String label) =>
      DateColumn(name, label, type, _data.build());
}

final class BoolColumnBuilder extends ColumnBuilder {
  BoolColumnBuilder(super.name);

  @override
  ColumnType get type => ColumnType.boolean;

  final _data = ByteBuffer();

  @override
  int get length => _data.length;

  @override
  void add(Object? value) =>
      _data.add(value == null ? 2 : (value as bool ? 1 : 0));

  @override
  Object? valueAt(int row) => switch (_data[row]) {
    0 => false,
    1 => true,
    _ => null,
  };

  @override
  FactColumnImpl build(String label) => BoolColumn(name, label, _data.build());
}

final class TextColumnBuilder extends ColumnBuilder {
  TextColumnBuilder(super.name);

  @override
  ColumnType get type => ColumnType.text;

  final _codes = IntBuffer();
  final _dict = <String>[];
  final _index = <String, int>{};

  @override
  int get length => _codes.length;

  @override
  void add(Object? value) {
    if (value == null) {
      _codes.add(-1);
      return;
    }
    final s = value as String;
    var code = _index[s];
    if (code == null) {
      code = _dict.length;
      _dict.add(s);
      _index[s] = code;
    }
    _codes.add(code);
  }

  @override
  Object? valueAt(int row) {
    final c = _codes[row];
    return c < 0 ? null : _dict[c];
  }

  @override
  FactColumnImpl build(String label) =>
      TextColumn(name, label, List.unmodifiable(_dict), _codes.build());
}

/// A built, immutable column.
abstract base class FactColumnImpl implements FactColumn {
  FactColumnImpl(this.name, this.label, this.type);

  @override
  final String name;
  @override
  final String label;
  @override
  final ColumnType type;

  int get length;

  /// A copy sharing this column's data under another [label].
  FactColumnImpl withLabel(String label);

  Object? valueAt(int row);

  /// Numeric view; only valid when [type] is numeric.
  double? numberAt(int row) => throw StateError('column $name is not numeric');

  @override
  late final int nullCount = _countNulls();

  @override
  late final int distinctCount = _countDistinct();

  int _countNulls() {
    var n = 0;
    for (var i = 0; i < length; i++) {
      if (valueAt(i) == null) n++;
    }
    return n;
  }

  int _countDistinct() {
    final seen = <Object?>{};
    for (var i = 0; i < length; i++) {
      seen.add(valueAt(i));
    }
    seen.remove(null);
    return seen.length;
  }
}

final class NumberColumn extends FactColumnImpl {
  NumberColumn(super.name, super.label, super.type, this.data);

  final Float64List data;

  @override
  NumberColumn withLabel(String label) => NumberColumn(name, label, type, data);

  @override
  int get length => data.length;

  @override
  Object? valueAt(int row) {
    final v = data[row];
    if (v.isNaN) return null;
    return type == ColumnType.integer ? v.toInt() : v;
  }

  @override
  double? numberAt(int row) {
    final v = data[row];
    return v.isNaN ? null : v;
  }
}

final class DateColumn extends FactColumnImpl {
  DateColumn(super.name, super.label, super.type, this.data);

  final Float64List data;

  @override
  DateColumn withLabel(String label) => DateColumn(name, label, type, data);

  @override
  int get length => data.length;

  @override
  Object? valueAt(int row) {
    final v = data[row];
    return v.isNaN
        ? null
        : DateTime.fromMillisecondsSinceEpoch(v.toInt(), isUtc: true);
  }
}

final class BoolColumn extends FactColumnImpl {
  BoolColumn(String name, String label, this.data)
    : super(name, label, ColumnType.boolean);

  final Uint8List data;

  @override
  BoolColumn withLabel(String label) => BoolColumn(name, label, data);

  @override
  int get length => data.length;

  @override
  Object? valueAt(int row) => switch (data[row]) {
    0 => false,
    1 => true,
    _ => null,
  };
}

final class TextColumn extends FactColumnImpl {
  TextColumn(String name, String label, this.dictionary, this.codes)
    : super(name, label, ColumnType.text);

  final List<String> dictionary;
  final Int32List codes;

  @override
  TextColumn withLabel(String label) =>
      TextColumn(name, label, dictionary, codes);

  @override
  int get length => codes.length;

  @override
  Object? valueAt(int row) {
    final c = codes[row];
    return c < 0 ? null : dictionary[c];
  }

  @override
  int _countDistinct() => dictionary.length;
}

final class FactTableImpl implements FactTable {
  FactTableImpl(this.schema, List<FactColumnImpl> columns, this.rowCount)
    : columns = List.unmodifiable(columns),
      _byName = {for (final c in columns) c.name: c};

  @override
  final Schema schema;

  @override
  final List<FactColumnImpl> columns;

  @override
  final int rowCount;

  final Map<String, FactColumnImpl> _byName;
  final _distinctCache = <Dimension, List<Object?>>{};

  @override
  FactColumnImpl column(String name) {
    final c = _byName[name];
    if (c == null) throw ArgumentError.value(name, 'name', 'unknown column');
    return c;
  }

  @override
  FactColumnImpl? findColumn(String name) => _byName[name];

  @override
  FactTableImpl withLabels(Map<String, String?> labels) => FactTableImpl(
    Schema([
      for (final c in schema.columns)
        if (labels.containsKey(c.name))
          ColumnSpec(
            name: c.name,
            type: c.type,
            label: labels[c.name],
            include: c.include,
            format: c.format,
            numberSyntax: c.numberSyntax,
            parser: c.parser,
            nullValues: c.nullValues,
          )
        else
          c,
    ]),
    [
      for (final c in columns)
        if (labels.containsKey(c.name))
          c.withLabel(labels[c.name] ?? c.name)
        else
          c,
    ],
    rowCount,
  );

  @override
  Object? valueAt(int row, String column) => this.column(column).valueAt(row);

  @override
  Object? dimensionValue(int row, Dimension dimension) {
    if (dimension is ExpressionDimension) {
      return materializeDimension(dimension).valueAt(row);
    }
    return dimension.valueOf(column(dimension.sourceColumn).valueAt(row));
  }

  @override
  double? measureValue(int row, Measure measure) {
    switch (measure) {
      case ColumnMeasure(:final column):
        final c = this.column(column);
        if (!c.type.isNumeric) {
          throw ArgumentError.value(column, 'measure', 'column is not numeric');
        }
        return c.numberAt(row);
      case ExpressionMeasure():
        final v = materializeMeasure(measure)[row];
        return v.isNaN ? null : v;
    }
  }

  final _measures = <Measure, Float64List>{};
  final _dimensions = <Dimension, FactColumnImpl>{};

  /// The values of [measure] for every row (NaN = null), computed on first
  /// use and cached.
  Float64List materializeMeasure(ExpressionMeasure measure) =>
      _measures.putIfAbsent(measure, () {
        final f = measure.expression
            .compile(
              this,
              scope: ExpressionScope.ofFacts(
                this,
                functions: measure.functions,
              ),
              expected: ExprType.number,
            )
            .asNumber;
        final data = Float64List(rowCount);
        for (var r = 0; r < rowCount; r++) {
          data[r] = f(r);
        }
        return data;
      });

  /// The values of [dimension] for every row as a column of its type,
  /// computed on first use and cached.
  FactColumnImpl materializeDimension(ExpressionDimension dimension) =>
      _dimensions.putIfAbsent(dimension, () {
        final compiled = dimension.expression.compile(
          this,
          scope: ExpressionScope.ofFacts(this, functions: dimension.functions),
        );
        final name = dimension.id, label = dimension.label;
        switch (compiled.type) {
          case ExprType.number:
            final f = compiled.asNumber;
            final data = Float64List(rowCount);
            var integral = true;
            for (var r = 0; r < rowCount; r++) {
              final v = data[r] = f(r);
              if (integral && !v.isNaN && v != v.truncateToDouble()) {
                integral = false;
              }
            }
            return NumberColumn(
              name,
              label,
              integral ? ColumnType.integer : ColumnType.number,
              data,
            );
          case ExprType.date:
            final f = compiled.asNumber;
            final data = Float64List(rowCount);
            var midnight = true;
            for (var r = 0; r < rowCount; r++) {
              final v = data[r] = f(r);
              if (midnight && !v.isNaN && v % 86400000 != 0) midnight = false;
            }
            return DateColumn(
              name,
              label,
              midnight ? ColumnType.date : ColumnType.dateTime,
              data,
            );
          case ExprType.boolean:
            final f = compiled.asBoolean;
            final data = Uint8List(rowCount);
            for (var r = 0; r < rowCount; r++) {
              data[r] = switch (f(r)) {
                false => 0,
                true => 1,
                null => 2,
              };
            }
            return BoolColumn(name, label, data);
          case ExprType.text:
            final f = compiled.asText;
            final index = <String, int>{};
            final dictionary = <String>[];
            final codes = Int32List(rowCount);
            for (var r = 0; r < rowCount; r++) {
              final v = f(r);
              codes[r] = v == null
                  ? -1
                  : index.putIfAbsent(v, () {
                      dictionary.add(v);
                      return dictionary.length - 1;
                    });
            }
            return TextColumn(name, label, dictionary, codes);
        }
      });

  /// The column whose stored value *is* the dimension's value: the source
  /// column of a [ColumnDimension], the materialized column of an
  /// [ExpressionDimension]; `null` for dimensions that transform values.
  FactColumnImpl? plainColumnOf(Dimension dimension) => switch (dimension) {
    ColumnDimension(:final sourceColumn) => column(sourceColumn),
    ExpressionDimension() => materializeDimension(dimension),
    DatePartDimension() || MappedDimension() => null,
  };

  @override
  List<Object?> distinctValues(Dimension dimension) =>
      _distinctCache.putIfAbsent(dimension, () {
        final seen = <Object?>{};
        for (var row = 0; row < rowCount; row++) {
          seen.add(dimensionValue(row, dimension));
        }
        return List.unmodifiable(seen.toList()..sort(dimension.compareValues));
      });

  @override
  int countWhere(Dimension dimension, Object? value) {
    var n = 0;
    for (var row = 0; row < rowCount; row++) {
      if (dimensionValue(row, dimension) == value) n++;
    }
    return n;
  }
}
