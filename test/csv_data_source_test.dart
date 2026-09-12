import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tessera/tessera.dart';

Future<List<List<Object?>>> rowsOf(DataSource s) => s.rows().toList();

/// Feeds [text] as UTF-8 bytes in chunks of [size] bytes, so multi-byte
/// characters, quoted fields and `\r\n` pairs get split across chunks.
CsvDataSource chunked(
  String text,
  int size, {
  CsvOptions options = const CsvOptions(),
}) {
  final bytes = utf8.encode(text);
  return CsvDataSource.fromBytes(() async* {
    for (var i = 0; i < bytes.length; i += size) {
      yield bytes.sublist(i, i + size > bytes.length ? bytes.length : i + size);
    }
  }, options: options);
}

void main() {
  group('CsvDataSource', () {
    test('parses header and simple rows', () async {
      final s = CsvDataSource.fromString('a,b,c\n1,2,3\n4,5,6\n');
      expect(await s.columnNames(), ['a', 'b', 'c']);
      expect(await rowsOf(s), [
        ['1', '2', '3'],
        ['4', '5', '6'],
      ]);
    });

    test('rows() can be iterated more than once', () async {
      final s = CsvDataSource.fromString('a\n1\n2\n');
      expect(await rowsOf(s), [
        ['1'],
        ['2'],
      ]);
      expect(await rowsOf(s), [
        ['1'],
        ['2'],
      ]);
    });

    test('quoted fields: delimiters, escaped quotes, newlines', () async {
      const text =
          'name,note\n'
          '"Smith, John","said ""hi"""\n'
          '"multi\nline",plain\n'
          '"",""\n';
      final s = CsvDataSource.fromString(text);
      expect(await rowsOf(s), [
        ['Smith, John', 'said "hi"'],
        ['multi\nline', 'plain'],
        ['', ''],
      ]);
    });

    test('accepts CRLF and bare CR line endings', () async {
      expect(await rowsOf(CsvDataSource.fromString('a,b\r\n1,2\r\n3,4')), [
        ['1', '2'],
        ['3', '4'],
      ]);
      expect(await rowsOf(CsvDataSource.fromString('a,b\r1,2\r3,4\r')), [
        ['1', '2'],
        ['3', '4'],
      ]);
    });

    test('strips a UTF-8 BOM and skips blank lines', () async {
      final s = CsvDataSource.fromString('﻿a,b\n\n1,2\n\n\n3,4\n\n');
      expect(await s.columnNames(), ['a', 'b']);
      expect(await rowsOf(s), [
        ['1', '2'],
        ['3', '4'],
      ]);
    });

    test('a quoted empty single field is not a blank line', () async {
      final s = CsvDataSource.fromString('a\n""\nx\n');
      expect(await rowsOf(s), [
        [''],
        ['x'],
      ]);
    });

    test('pads short records with null, keeps long ones', () async {
      final s = CsvDataSource.fromString('a,b,c\n1\n1,2,3,4\n');
      expect(await rowsOf(s), [
        ['1', null, null],
        ['1', '2', '3', '4'],
      ]);
    });

    test('no header → column1..n from the first record', () async {
      final s = CsvDataSource.fromString(
        '1,2,3\n4,5,6\n',
        options: const CsvOptions(hasHeader: false),
      );
      expect(await s.columnNames(), ['column1', 'column2', 'column3']);
      expect((await rowsOf(s)).length, 2);
    });

    test('skipLeadingLines, delimiter and trimCells options', () async {
      const text = '# generated\r\n# by hand\r\na ; b\r\n 1 ;" 2 "\r\n';
      final s = CsvDataSource.fromString(
        text,
        options: const CsvOptions(
          delimiter: ';',
          skipLeadingLines: 2,
          trimCells: true,
        ),
      );
      expect(await s.columnNames(), ['a', 'b']);
      // quoted cells are never trimmed
      expect(await rowsOf(s), [
        ['1', ' 2 '],
      ]);
    });

    test('header names are trimmed and made unique', () async {
      final s = CsvDataSource.fromString(' a ,a,,a\n1,2,3,4\n');
      expect(await s.columnNames(), ['a', 'a_2', 'column3', 'a_3']);
    });

    test('lenient: stray quotes and unterminated quote', () async {
      final s = CsvDataSource.fromString('a,b\nx"y,"unterminated\n');
      expect(await rowsOf(s), [
        ['x"y', 'unterminated\n'],
      ]);
    });

    test('empty input', () async {
      final s = CsvDataSource.fromString('');
      expect(await s.columnNames(), isEmpty);
      expect(await rowsOf(s), isEmpty);
    });

    test('byte chunks of any size give identical results', () async {
      const text =
          'név,note\r\n'
          'Kovács Anna,"a, ""b""\r\nc"\r\n'
          'Szabó Éva,ő\r\n';
      final expected = await rowsOf(CsvDataSource.fromString(text));
      expect(expected, [
        ['Kovács Anna', 'a, "b"\r\nc'],
        ['Szabó Éva', 'ő'],
      ]);
      for (final size in [1, 2, 3, 5, 7, 64]) {
        final s = chunked(text, size);
        expect(await s.columnNames(), ['név', 'note'], reason: 'chunk $size');
        expect(await rowsOf(s), expected, reason: 'chunk $size');
      }
    });

    test('fromData reads in-memory bytes and knows its length', () async {
      final s = CsvDataSource.fromData(utf8.encode('a,b\nx,y\n'));
      expect(await s.columnNames(), ['a', 'b']);
      expect(await rowsOf(s), [
        ['x', 'y'],
      ]);
      expect(await s.estimatedRowCount(), 1);
    });

    test('latin-1 encoding', () async {
      final bytes = latin1.encode('a\nKovács\n');
      final s = CsvDataSource.fromBytes(
        () => Stream.value(bytes),
        encoding: latin1,
      );
      expect(await rowsOf(s), [
        ['Kovács'],
      ]);
    });
  });
}
