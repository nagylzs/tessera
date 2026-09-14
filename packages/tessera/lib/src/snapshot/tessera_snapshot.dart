import 'dart:convert';
import 'dart:typed_data';

import '../facts/fact_table.dart';
import '../facts/fact_table_impl.dart';
import '../json/cube_json.dart';
import '../schema/column_type.dart';

/// What a snapshot holds: the facts and, optionally, a pivot configuration
/// that was stored with them.
final class SnapshotContents {
  const SnapshotContents(this.facts, {this.config});

  final FactTable facts;
  final CubeConfig? config;
}

/// The binary snapshot format: a [FactTable] (and optionally a
/// [CubeConfig]) as one buffer of bytes that loads back in a copy, without
/// parsing or inference.
///
/// Use it to cache an import, or to build the table on a server and send
/// it to a client — the client then never sees the source file. The layout
/// is documented in `docs/snapshot.md` at the repository root, so any
/// language can write it: a magic, a version, a JSON header describing the
/// columns, then the raw little-endian column arrays, each at an 8-byte
/// aligned offset. Nothing is compressed; leave that to the transport
/// (HTTP content encoding) or the file layer (gzip).
///
/// [decode] validates every offset, length and code before trusting the
/// data and throws [FormatException] on anything malformed, including a
/// newer [formatVersion] than this library knows.
final class TesseraSnapshot {
  const TesseraSnapshot({this.codec = CubeJson.standard});

  /// Encodes and decodes the schema and the configuration.
  final CubeJson codec;

  /// The first four bytes of every snapshot.
  static const magic = 'TSNP';

  /// The version this library writes and the newest it reads.
  static const formatVersion = 1;

  static const _alignment = 8;

  // ---------------------------------------------------------------- encode

  Uint8List encode(FactTable facts, {CubeConfig? config}) {
    final impl = _asImpl(facts);
    final sections = <Uint8List>[];
    final columns = <Map<String, Object?>>[];
    var offset = 0;

    int addSection(Uint8List bytes) {
      final start = offset;
      sections.add(bytes);
      offset += _padded(bytes.length);
      return start;
    }

    for (final c in impl.columns) {
      final json = <String, Object?>{
        'name': c.name,
        'label': c.label,
        'type': c.type.name,
      };
      switch (c) {
        case NumberColumn(:final data):
        case DateColumn(:final data):
          json['data'] = {
            'encoding': 'f64',
            'offset': addSection(_bytesOf(data)),
            'length': data.lengthInBytes,
          };
        case BoolColumn(:final data):
          json['data'] = {
            'encoding': 'u8',
            'offset': addSection(data),
            'length': data.lengthInBytes,
          };
        case TextColumn(:final dictionary, :final codes):
          final dict = _encodeDictionary(dictionary);
          json['dictionary'] = {
            'count': dictionary.length,
            'offset': addSection(dict),
            'length': dict.length,
          };
          final (encoding, bytes) = _encodeCodes(codes, dictionary.length);
          json['codes'] = {
            'encoding': encoding,
            'offset': addSection(bytes),
            'length': bytes.length,
          };
      }
      columns.add(json);
    }

    final header = utf8.encode(
      jsonEncode({
        'rows': impl.rowCount,
        'schema': codec.encodeSchema(impl.schema),
        'columns': columns,
        if (config != null) 'config': codec.encodeConfig(config),
      }),
    );
    final headerEnd = 12 + header.length;
    final dataStart = _padded(headerEnd);
    final out = Uint8List(dataStart + offset);
    final view = ByteData.sublistView(out);
    out.setRange(0, 4, magic.codeUnits);
    view.setUint32(4, formatVersion, Endian.little);
    view.setUint32(8, header.length, Endian.little);
    out.setRange(12, headerEnd, header);
    var pos = dataStart;
    for (final s in sections) {
      out.setRange(pos, pos + s.length, s);
      pos += _padded(s.length);
    }
    return out;
  }

  static int _padded(int length) =>
      (length + _alignment - 1) ~/ _alignment * _alignment;

  static Uint8List _bytesOf(Float64List data) {
    if (Endian.host != Endian.little) {
      throw UnsupportedError('snapshots need a little-endian host');
    }
    return Uint8List.sublistView(data);
  }

  /// `count` × uint32 byte lengths, then the UTF-8 bytes back to back.
  static Uint8List _encodeDictionary(List<String> dictionary) {
    final encoded = [for (final s in dictionary) utf8.encode(s)];
    var total = 4 * encoded.length;
    for (final e in encoded) {
      total += e.length;
    }
    final out = Uint8List(total);
    final view = ByteData.sublistView(out);
    var pos = 4 * encoded.length;
    for (var i = 0; i < encoded.length; i++) {
      view.setUint32(4 * i, encoded[i].length, Endian.little);
      out.setRange(pos, pos + encoded[i].length, encoded[i]);
      pos += encoded[i].length;
    }
    return out;
  }

  /// The narrowest signed width that holds every code (and -1).
  static (String, Uint8List) _encodeCodes(Int32List codes, int count) {
    if (count <= 127) {
      final out = Int8List(codes.length);
      for (var i = 0; i < codes.length; i++) {
        out[i] = codes[i];
      }
      return ('i8', Uint8List.sublistView(out));
    }
    if (count <= 32767) {
      final out = Int16List(codes.length);
      for (var i = 0; i < codes.length; i++) {
        out[i] = codes[i];
      }
      return ('i16', Uint8List.sublistView(out));
    }
    if (Endian.host != Endian.little) {
      throw UnsupportedError('snapshots need a little-endian host');
    }
    return ('i32', Uint8List.sublistView(codes));
  }

  /// Any [FactTable] as the engine's columnar table (a copy through the
  /// public interface when it is not one already).
  static FactTableImpl _asImpl(FactTable facts) {
    if (facts is FactTableImpl) return facts;
    final columns = <FactColumnImpl>[];
    for (final c in facts.columns) {
      final b = ColumnBuilder.create(c.name, c.type);
      for (var r = 0; r < facts.rowCount; r++) {
        b.add(facts.valueAt(r, c.name));
      }
      columns.add(b.build(c.label));
    }
    return FactTableImpl(facts.schema, columns, facts.rowCount);
  }

  // ---------------------------------------------------------------- decode

  SnapshotContents decode(Uint8List bytes) {
    if (bytes.length < 12 || String.fromCharCodes(bytes, 0, 4) != magic) {
      throw const FormatException('not a Tessera snapshot');
    }
    final view = ByteData.sublistView(bytes);
    final version = view.getUint32(4, Endian.little);
    if (version < 1 || version > formatVersion) {
      throw FormatException(
        'snapshot format version $version is newer than the supported '
        '$formatVersion',
      );
    }
    final headerLength = view.getUint32(8, Endian.little);
    if (12 + headerLength > bytes.length) {
      throw const FormatException('snapshot header is truncated');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes.sublist(12, 12 + headerLength)));
    } on FormatException catch (e) {
      throw FormatException('snapshot header: ${e.message}');
    }
    if (decoded is! Map) {
      throw const FormatException('snapshot header is not an object');
    }
    final header = decoded.cast<String, Object?>();
    final rows = header['rows'];
    if (rows is! int || rows < 0) {
      throw const FormatException('snapshot header: invalid "rows"');
    }
    final dataStart = _padded(12 + headerLength);
    final schema = codec.decodeSchema(_map(header, 'schema'));
    final columns = <FactColumnImpl>[];
    final columnsJson = header['columns'];
    if (columnsJson is! List) {
      throw const FormatException('snapshot header: "columns" is not a list');
    }
    for (final c in columnsJson) {
      if (c is! Map) {
        throw const FormatException(
          'snapshot header: a column is not an object',
        );
      }
      columns.add(
        _decodeColumn(c.cast<String, Object?>(), bytes, dataStart, rows),
      );
    }
    final names = {for (final c in columns) c.name};
    for (final s in schema.included) {
      if (!names.contains(s.name)) {
        throw FormatException('snapshot: column "${s.name}" has no data');
      }
    }
    final facts = FactTableImpl(schema, columns, rows);
    final configJson = header['config'];
    return SnapshotContents(
      facts,
      config: configJson == null
          ? null
          : codec.decodeConfig(_map(header, 'config')),
    );
  }

  FactColumnImpl _decodeColumn(
    Map<String, Object?> json,
    Uint8List bytes,
    int dataStart,
    int rows,
  ) {
    final name = _string(json, 'name');
    final label = json['label'] is String ? json['label'] as String : name;
    final typeName = _string(json, 'type');
    final type = ColumnType.values.where((t) => t.name == typeName).firstOrNull;
    if (type == null) {
      throw FormatException(
        'snapshot: column "$name" has unknown type "$typeName"',
      );
    }
    switch (type) {
      case ColumnType.integer || ColumnType.number:
        return NumberColumn(
          name,
          label,
          type,
          _float64s(json, bytes, dataStart, rows, name),
        );
      case ColumnType.date || ColumnType.dateTime:
        return DateColumn(
          name,
          label,
          type,
          _float64s(json, bytes, dataStart, rows, name),
        );
      case ColumnType.boolean:
        final section = _section(
          _map(json, 'data'),
          bytes,
          dataStart,
          name,
          'u8',
          rows,
          1,
        );
        for (var i = 0; i < section.length; i++) {
          if (section[i] > 2) {
            throw FormatException(
              'snapshot: column "$name" has an invalid boolean',
            );
          }
        }
        return BoolColumn(name, label, Uint8List.fromList(section));
      case ColumnType.text:
        final dictJson = _map(json, 'dictionary');
        final count = dictJson['count'];
        if (count is! int || count < 0) {
          throw FormatException(
            'snapshot: column "$name" has an invalid dictionary count',
          );
        }
        final dictionary = _decodeDictionary(
          _section(dictJson, bytes, dataStart, name, null, null, null),
          count,
          name,
        );
        final codesJson = _map(json, 'codes');
        final encoding = _string(codesJson, 'encoding');
        final width = switch (encoding) {
          'i8' => 1,
          'i16' => 2,
          'i32' => 4,
          _ => throw FormatException(
            'snapshot: column "$name" has unknown code encoding "$encoding"',
          ),
        };
        final section = _section(
          codesJson,
          bytes,
          dataStart,
          name,
          encoding,
          rows,
          width,
        );
        final codes = Int32List(rows);
        final data = ByteData.sublistView(section);
        for (var i = 0; i < rows; i++) {
          final code = switch (width) {
            1 => data.getInt8(i),
            2 => data.getInt16(2 * i, Endian.little),
            _ => data.getInt32(4 * i, Endian.little),
          };
          if (code < -1 || code >= count) {
            throw FormatException(
              'snapshot: column "$name" has a code out of range',
            );
          }
          codes[i] = code;
        }
        return TextColumn(name, label, dictionary, codes);
    }
  }

  Float64List _float64s(
    Map<String, Object?> json,
    Uint8List bytes,
    int dataStart,
    int rows,
    String name,
  ) {
    final section = _section(
      _map(json, 'data'),
      bytes,
      dataStart,
      name,
      'f64',
      rows,
      8,
    );
    final out = Float64List(rows);
    if (Endian.host == Endian.little) {
      Uint8List.sublistView(out).setAll(0, section);
    } else {
      final data = ByteData.sublistView(section);
      for (var i = 0; i < rows; i++) {
        out[i] = data.getFloat64(8 * i, Endian.little);
      }
    }
    return out;
  }

  /// The bytes of a section, checked against the buffer; with [expected]
  /// rows × [width] the length must match exactly.
  static Uint8List _section(
    Map<String, Object?> json,
    Uint8List bytes,
    int dataStart,
    String name,
    String? encoding,
    int? rows,
    int? width,
  ) {
    if (encoding != null && json['encoding'] != encoding) {
      throw FormatException(
        'snapshot: column "$name" has encoding "${json['encoding']}", expected "$encoding"',
      );
    }
    final offset = json['offset'], length = json['length'];
    if (offset is! int || length is! int || offset < 0 || length < 0) {
      throw FormatException('snapshot: column "$name" has an invalid section');
    }
    if (offset % _alignment != 0) {
      throw FormatException(
        'snapshot: column "$name" section is not 8-byte aligned',
      );
    }
    if (rows != null && length != rows * width!) {
      throw FormatException(
        'snapshot: column "$name" has $length bytes, expected ${rows * width}',
      );
    }
    final start = dataStart + offset;
    if (start + length > bytes.length) {
      throw FormatException(
        'snapshot: column "$name" section exceeds the buffer',
      );
    }
    return Uint8List.sublistView(bytes, start, start + length);
  }

  static List<String> _decodeDictionary(
    Uint8List section,
    int count,
    String name,
  ) {
    if (section.length < 4 * count) {
      throw FormatException('snapshot: column "$name" dictionary is truncated');
    }
    final view = ByteData.sublistView(section);
    final out = <String>[];
    var pos = 4 * count;
    for (var i = 0; i < count; i++) {
      final len = view.getUint32(4 * i, Endian.little);
      if (pos + len > section.length) {
        throw FormatException(
          'snapshot: column "$name" dictionary is truncated',
        );
      }
      try {
        out.add(utf8.decode(Uint8List.sublistView(section, pos, pos + len)));
      } on FormatException {
        throw FormatException(
          'snapshot: column "$name" dictionary is not UTF-8',
        );
      }
      pos += len;
    }
    return out;
  }

  static Map<String, Object?> _map(Map<String, Object?> json, String key) {
    final v = json[key];
    if (v is Map) return v.cast<String, Object?>();
    throw FormatException('snapshot header: "$key" is not an object');
  }

  static String _string(Map<String, Object?> json, String key) {
    final v = json[key];
    if (v is String) return v;
    throw FormatException('snapshot header: "$key" is not a string');
  }
}
