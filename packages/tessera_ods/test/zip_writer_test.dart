import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:test/test.dart';
import 'package:tessera/tessera.dart';
import 'package:tessera_ods/src/zip_writer.dart';
import 'package:tessera_ods/tessera_ods.dart';

typedef Header = ({
  String name,
  int flags,
  int method,
  int crc,
  int compressedSize,
  int size,
  int extraLength,
  int offset,
});

/// Walks [zip] from the start: the local headers back to back, then the
/// central directory right after them — so no data descriptor (bit 3) may
/// sit between an entry and the next — then the end record. Returns the
/// local headers after checking that every central header agrees.
List<Header> headersOf(Uint8List zip) {
  final b = ByteData.sublistView(zip);
  int u16(int at) => b.getUint16(at, Endian.little);
  int u32(int at) => b.getUint32(at, Endian.little);
  String name(int at, int length) => utf8.decode(zip.sublist(at, at + length));

  final locals = <Header>[];
  var at = 0;
  while (u32(at) == 0x04034b50) {
    final header = (
      name: name(at + 30, u16(at + 26)),
      flags: u16(at + 6),
      method: u16(at + 8),
      crc: u32(at + 14),
      compressedSize: u32(at + 18),
      size: u32(at + 22),
      extraLength: u16(at + 28),
      offset: at,
    );
    locals.add(header);
    at += 30 + u16(at + 26) + u16(at + 28) + header.compressedSize;
  }
  final directoryStart = at;
  for (final local in locals) {
    expect(u32(at), 0x02014b50, reason: 'central header of ${local.name}');
    final central = (
      name: name(at + 46, u16(at + 28)),
      flags: u16(at + 8),
      method: u16(at + 10),
      crc: u32(at + 16),
      compressedSize: u32(at + 20),
      size: u32(at + 24),
      extraLength: u16(at + 30),
      offset: u32(at + 42),
    );
    expect(central, local);
    at += 46 + u16(at + 28) + u16(at + 30) + u16(at + 32);
  }
  expect(u32(at), 0x06054b50, reason: 'end of central directory');
  expect(u16(at + 10), locals.length);
  expect(u32(at + 12), at - directoryStart);
  expect(u32(at + 16), directoryStart);
  expect(at + 22, zip.length);
  return locals;
}

void main() {
  test('entries round-trip, deflated or stored', () {
    final big = List.filled(5000, '<row>tessera</row>').join();
    final zip =
        (ZipWriter()
              ..addText('stored', 'kept as is', store: true)
              ..addText('a/big.xml', big)
              ..addText('empty', '')
              ..addText('ékezet.txt', 'árvíztűrő tükörfúrógép'))
            .finish();
    final archive = ZipDecoder().decodeBytes(zip);
    String text(String name) => utf8.decode(archive.find(name)!.content);
    expect(archive.map((f) => f.name), [
      'stored',
      'a/big.xml',
      'empty',
      'ékezet.txt',
    ]);
    expect(text('stored'), 'kept as is');
    expect(text('a/big.xml'), big);
    expect(text('empty'), '');
    expect(text('ékezet.txt'), 'árvíztűrő tükörfúrógép');

    final headers = headersOf(zip);
    expect(headers.map((h) => h.method), [0, 8, 8, 8]);
    expect(headers[1].compressedSize, lessThan(big.length ~/ 50));
    expect(headers.map((h) => h.flags), [0, 0, 0, 0x0800]);
  });

  test('the same input gives the same bytes', () {
    Uint8List build() =>
        (ZipWriter()
              ..addText('a', 'x' * 1000)
              ..addText('b', 'y', store: true))
            .finish();
    expect(build(), build());
  });

  test('an exported document: mimetype first and stored, no descriptors', () {
    final ods = const OdsTableExporter().export(
      ExportTable(
        const [ExportColumn('Name'), ExportColumn('Amount')],
        [
          ['Kovács Anna', 171207.0],
        ],
      ),
    );
    final headers = headersOf(ods);
    final mimetype = headers.first;
    expect(mimetype.name, 'mimetype');
    expect(mimetype.method, 0);
    expect(mimetype.extraLength, 0);
    // Readers sniff the type at a fixed offset: 30 + "mimetype".length.
    expect(
      ascii.decode(ods.sublist(38, 38 + mimetype.size)),
      'application/vnd.oasis.opendocument.spreadsheet',
    );
    expect(headers.map((h) => h.name), contains('content.xml'));
    for (final h in headers) {
      expect(h.flags & 8, 0, reason: h.name);
      expect(h.extraLength, 0, reason: h.name);
    }
  });
}
