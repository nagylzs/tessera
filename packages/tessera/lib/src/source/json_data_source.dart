import 'dart:convert';

import '../schema/schema.dart';
import 'data_source.dart';

/// Options shared by [JsonDataSource] and [JsonlDataSource].
final class JsonOptions {
  const JsonOptions({
    this.flatten = true,
    this.separator = '.',
    this.columns,
    this.scanAllRows = false,
  });

  /// Turn nested objects into dotted columns: `{"address": {"city": …}}`
  /// becomes a column `address.city`. When `false`, a nested object is
  /// stored as its JSON text. Arrays are always stored as JSON text.
  final bool flatten;

  /// The separator between the parts of a flattened name.
  final String separator;

  /// The columns to read, in this order; keys not listed are ignored and
  /// listed keys that a record lacks are `null`. Default: the keys found in
  /// the data (see [scanAllRows]).
  final List<String>? columns;

  /// [JsonlDataSource] only: take the column names from the union of every
  /// record's keys (a full extra pass over the file) instead of the first
  /// record's. A JSON array is parsed whole, so its columns are always the
  /// union.
  final bool scanAllRows;
}

/// What the two sources have in common: value conversion and flattening.
abstract base class _JsonSource implements DataSource {
  _JsonSource(this.name, this.options);

  @override
  final String name;

  final JsonOptions options;

  /// Always `null`: the types come from the values themselves and are
  /// inferred like any other source's.
  @override
  Schema? get declaredSchema => null;

  /// The (flattened) key → value pairs of one record, in key order.
  Map<String, Object?> fields(Map<String, Object?> record) {
    if (!options.flatten) return record;
    final out = <String, Object?>{};
    void visit(Map<String, Object?> map, String prefix) {
      for (final e in map.entries) {
        final key = prefix.isEmpty
            ? e.key
            : '$prefix${options.separator}${e.key}';
        final v = e.value;
        if (v is Map<String, Object?>) {
          visit(v, key);
        } else if (v is Map) {
          visit(v.cast<String, Object?>(), key);
        } else {
          out[key] = v;
        }
      }
    }

    visit(record, '');
    return out;
  }

  /// A JSON value as a cell: scalars as they are, containers as JSON text.
  static Object? cell(Object? v) => switch (v) {
    null || num() || String() || bool() => v,
    _ => jsonEncode(v),
  };

  /// The record's cells in the order of [columns].
  SourceRow rowOf(Map<String, Object?> record, List<String> columns) {
    final f = fields(record);
    return [for (final c in columns) cell(f[c])];
  }

  /// Adds the keys of [record] to [names] (first seen first).
  void collectNames(Map<String, Object?> record, Set<String> names) {
    names.addAll(fields(record).keys);
  }

  static Map<String, Object?> asRecord(Object? v, String where) {
    if (v is Map<String, Object?>) return v;
    if (v is Map) return v.cast<String, Object?>();
    throw FormatException('$where: expected an object, got ${_kind(v)}');
  }

  static String _kind(Object? v) => switch (v) {
    null => 'null',
    List() => 'an array',
    num() => 'a number',
    String() => 'a string',
    bool() => 'a boolean',
    _ => v.runtimeType.toString(),
  };
}

/// A [DataSource] over a JSON document whose top level is an array of
/// objects: `[{"region": "Europe", "total": 12.5}, …]`.
///
/// Values keep their JSON types — numbers, booleans and `null` are stored
/// as such and only strings go through the schema's parsers, which is how
/// an ISO date string becomes a date. Nested objects are flattened into
/// dotted columns and arrays stored as JSON text ([JsonOptions]). The
/// column names are the union of every object's keys in first-seen order,
/// unless [JsonOptions.columns] names them.
///
/// The document is parsed whole with `jsonDecode` and the decoded records
/// are kept for the source's lifetime (inference and import both read
/// them), so this is for documents that fit in memory comfortably; a
/// large file is better off as JSON Lines ([JsonlDataSource]), which
/// streams.
final class JsonDataSource extends _JsonSource {
  /// Reads from JSON text already in memory.
  JsonDataSource.fromString(
    String text, {
    String name = 'json',
    JsonOptions options = const JsonOptions(),
  }) : _load = (() async => text),
       super(name, options);

  /// Reads from bytes already in memory. Sendable to another isolate.
  JsonDataSource.fromData(
    List<int> bytes, {
    String name = 'json',
    JsonOptions options = const JsonOptions(),
    Encoding encoding = utf8,
  }) : _load = (() async => encoding.decode(bytes)),
       super(name, options);

  /// Reads from a re-openable byte stream; [open] is invoked once, the
  /// first time the source is read.
  JsonDataSource.fromBytes(
    Stream<List<int>> Function() open, {
    String name = 'json',
    JsonOptions options = const JsonOptions(),
    Encoding encoding = utf8,
  }) : _load = (() => open().transform(encoding.decoder).join()),
       super(name, options);

  final Future<String> Function() _load;
  List<Map<String, Object?>>? _records;
  List<String>? _columnNames;

  Future<List<Map<String, Object?>>> _decoded() async {
    final cached = _records;
    if (cached != null) return cached;
    final Object? doc;
    try {
      doc = jsonDecode(await _load());
    } on FormatException catch (e) {
      throw FormatException('$name: ${e.message}');
    }
    if (doc is! List) {
      throw FormatException(
        '$name: expected a JSON array of objects at the top level, '
        'got ${_JsonSource._kind(doc)}',
      );
    }
    final records = <Map<String, Object?>>[];
    for (var i = 0; i < doc.length; i++) {
      records.add(_JsonSource.asRecord(doc[i], '$name: element $i'));
    }
    return _records = records;
  }

  @override
  Future<List<String>> columnNames() async {
    final cached = _columnNames;
    if (cached != null) return cached;
    final given = options.columns;
    if (given != null) return _columnNames = List.unmodifiable(given);
    final names = <String>{};
    for (final r in await _decoded()) {
      collectNames(r, names);
    }
    return _columnNames = List.unmodifiable(names);
  }

  @override
  Stream<SourceRow> rows() async* {
    final columns = await columnNames();
    for (final r in await _decoded()) {
      yield rowOf(r, columns);
    }
  }

  /// Exact: the number of objects in the array.
  @override
  Future<int?> estimatedRowCount() async => (await _decoded()).length;
}

/// A [DataSource] over JSON Lines: one JSON object per line
/// (`.jsonl` / `.ndjson`), read incrementally so the file never has to be
/// in memory at once.
///
/// Values are handled as in [JsonDataSource]. The column names are the
/// keys of the first record — or of every record with
/// [JsonOptions.scanAllRows], at the cost of one extra pass — unless
/// [JsonOptions.columns] names them. Blank lines are skipped; a line that
/// is not a JSON object is a [FormatException] naming the line.
final class JsonlDataSource extends _JsonSource {
  /// Reads from text already in memory.
  JsonlDataSource.fromString(
    String text, {
    String name = 'jsonl',
    JsonOptions options = const JsonOptions(),
  }) : _openText = (() => Stream.value(text)),
       _length = text.length,
       super(name, options);

  /// Reads from a re-openable byte stream; [open] is invoked once per
  /// iteration. Pass the total [length] in bytes when known to enable
  /// [estimatedRowCount].
  JsonlDataSource.fromBytes(
    Stream<List<int>> Function() open, {
    String name = 'jsonl',
    JsonOptions options = const JsonOptions(),
    Encoding encoding = utf8,
    this._length,
  }) : _openText = (() => open().transform(encoding.decoder)),
       super(name, options);

  /// Reads from bytes already in memory. Sendable to another isolate.
  JsonlDataSource.fromData(
    List<int> bytes, {
    String name = 'jsonl',
    JsonOptions options = const JsonOptions(),
    Encoding encoding = utf8,
  }) : _openText = (() => Stream.value(encoding.decode(bytes))),
       _length = bytes.length,
       super(name, options);

  static const _estimateSample = 200;

  final Stream<String> Function() _openText;
  final int? _length;
  List<String>? _columnNames;
  int? _estimatedRows;

  /// Non-blank lines with their 1-based line numbers.
  Stream<(int, String)> _lines() async* {
    var n = 0;
    await for (final line in _openText().transform(const LineSplitter())) {
      n++;
      if (line.trim().isEmpty) continue;
      yield (n, line);
    }
  }

  Map<String, Object?> _record(int line, String text) {
    final Object? v;
    try {
      v = jsonDecode(text);
    } on FormatException catch (e) {
      throw FormatException('$name, line $line: ${e.message}');
    }
    return _JsonSource.asRecord(v, '$name, line $line');
  }

  @override
  Future<List<String>> columnNames() async {
    final cached = _columnNames;
    if (cached != null) return cached;
    final given = options.columns;
    if (given != null) return _columnNames = List.unmodifiable(given);
    final names = <String>{};
    await for (final (n, text) in _lines()) {
      collectNames(_record(n, text), names);
      if (!options.scanAllRows) break;
    }
    return _columnNames = List.unmodifiable(names);
  }

  @override
  Stream<SourceRow> rows() async* {
    final columns = await columnNames();
    await for (final (n, text) in _lines()) {
      yield rowOf(_record(n, text), columns);
    }
  }

  /// Total length divided by the average length of the first
  /// [_estimateSample] lines; `null` when the length is unknown. Exact when
  /// the source is shorter than the sample.
  @override
  Future<int?> estimatedRowCount() async {
    final cached = _estimatedRows;
    if (cached != null) return cached;
    final length = _length;
    if (length == null) return null;
    var records = 0, characters = 0, complete = true;
    await for (final (_, text) in _lines()) {
      records++;
      characters += text.length + 1;
      if (records >= _estimateSample) {
        complete = false;
        break;
      }
    }
    final rows = complete || records == 0
        ? records
        : (length / (characters / records)).round();
    return _estimatedRows = rows;
  }
}
