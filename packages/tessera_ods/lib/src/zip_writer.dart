import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// A minimal zip writer for the exporters: each entry deflated or stored,
/// its CRC and sizes in the local header, the central directory after the
/// entries. Internal; the same file is in tessera_xlsx.
///
/// Not `archive`'s `ZipEncoder`: from 4.4.0 it streams every entry with a
/// data descriptor that only the local header announces (general purpose
/// bit 3), and LibreOffice refuses such a file ("source file could not be
/// loaded"). The exporters build their parts in memory anyway, so writing
/// the sizes up front costs nothing.
final class ZipWriter {
  final _entries = BytesBuilder(copy: false);
  final _directory = BytesBuilder(copy: false);
  int _count = 0;

  /// 1980-01-01 00:00, the earliest DOS date: the same input always gives
  /// the same bytes.
  static const _dosTime = 0;
  static const _dosDate = (1 << 5) | 1;

  /// Adds [text] as UTF-8 under [path].
  void addText(String path, String text, {bool store = false}) =>
      add(path, utf8.encode(text), store: store);

  /// Adds [content] under [path], deflated unless [store] (an OpenDocument
  /// `mimetype` must be stored).
  void add(String path, Uint8List content, {bool store = false}) {
    final name = utf8.encode(path);
    final data = store ? content : _deflate(content);
    final offset = _entries.length;
    if (content.length > 0xFFFFFFFF ||
        offset + 30 + name.length + data.length > 0xFFFFFFFF ||
        _count == 0xFFFF) {
      throw UnsupportedError('zip64 is not supported (4 GB, 65535 entries)');
    }
    // Bit 11: the name is UTF-8. Bit 3 (data descriptor) is never set.
    final flags = name.length == path.length ? 0 : 0x0800;
    final method = store ? 0 : 8;
    final crc = getCrc32(content);

    // Version needed, flags, method, time, date, CRC, sizes, name length and
    // an empty extra field: the local header from offset 4 and the central
    // header from offset 6 agree on all of them.
    void shared(ByteData b, int at) => b
      ..setUint16(at, 20, Endian.little)
      ..setUint16(at + 2, flags, Endian.little)
      ..setUint16(at + 4, method, Endian.little)
      ..setUint16(at + 6, _dosTime, Endian.little)
      ..setUint16(at + 8, _dosDate, Endian.little)
      ..setUint32(at + 10, crc, Endian.little)
      ..setUint32(at + 14, data.length, Endian.little)
      ..setUint32(at + 18, content.length, Endian.little)
      ..setUint16(at + 22, name.length, Endian.little)
      ..setUint16(at + 24, 0, Endian.little);

    final local = ByteData(30)..setUint32(0, 0x04034b50, Endian.little);
    shared(local, 4);
    _entries
      ..add(local.buffer.asUint8List())
      ..add(name)
      ..add(data);

    // Made by MS-DOS 2.0; no comment, disk 0, no attributes.
    final central = ByteData(46)
      ..setUint32(0, 0x02014b50, Endian.little)
      ..setUint16(4, 20, Endian.little)
      ..setUint32(42, offset, Endian.little);
    shared(central, 6);
    _directory
      ..add(central.buffer.asUint8List())
      ..add(name);
    _count++;
  }

  /// The zip file. The writer is empty afterwards.
  Uint8List finish() {
    final directory = _directory.takeBytes();
    final end = ByteData(22)
      ..setUint32(0, 0x06054b50, Endian.little)
      ..setUint16(8, _count, Endian.little)
      ..setUint16(10, _count, Endian.little)
      ..setUint32(12, directory.length, Endian.little)
      ..setUint32(16, _entries.length, Endian.little);
    _entries
      ..add(directory)
      ..add(end.buffer.asUint8List());
    _count = 0;
    return _entries.takeBytes();
  }

  /// Raw deflate, as a zip entry holds it: the zlib stream without its
  /// 2-byte header and Adler-32 trailer. `ZLibEncoder` is the platform's
  /// zlib on the VM (much faster than the pure-Dart `Deflate`, which is the
  /// fallback should the header ever announce a preset dictionary).
  static Uint8List _deflate(Uint8List bytes) {
    final zlib = const ZLibEncoder().encodeBytes(
      bytes,
      level: DeflateLevel.bestSpeed,
    );
    if (zlib.length < 6 || zlib[0] & 0x0F != 8 || zlib[1] & 0x20 != 0) {
      return Deflate(bytes, level: DeflateLevel.bestSpeed).getBytes();
    }
    return Uint8List.sublistView(zlib, 2, zlib.length - 4);
  }
}
