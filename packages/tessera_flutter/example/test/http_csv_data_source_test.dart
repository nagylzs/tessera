import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tessera/tessera.dart';
import 'package:tessera_example/common/http_csv_data_source.dart';

/// Serves [body] at `/data.csv`; `/chunked.csv` streams it without a
/// Content-Length; `/missing.csv` is a 404. Counts requests.
Future<(HttpServer, List<String>)> serve(String body) async {
  final requests = <String>[];
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    requests.add('${request.method} ${request.uri.path}');
    final response = request.response;
    switch (request.uri.path) {
      case '/data.csv':
        response.headers.contentType = ContentType('text', 'csv');
        response.contentLength = utf8.encode(body).length;
        if (request.method != 'HEAD') response.write(body);
      case '/chunked.csv':
        response.headers.contentType = ContentType('text', 'csv');
        // one line per chunk, no length
        for (final line in const LineSplitter().convert(body)) {
          response.write('$line\n');
          await response.flush();
        }
      default:
        response.statusCode = HttpStatus.notFound;
    }
    await response.close();
  });
  return (server, requests);
}

String csv(int rows) {
  final b = StringBuffer('id,name,value\n');
  for (var i = 0; i < rows; i++) {
    // fixed-width rows so the length-based estimate is exact
    b.writeln(
      '${i.toString().padLeft(6, '0')},name${i.toString().padLeft(6, '0')},${(i * 1.5).toStringAsFixed(1).padLeft(9, '0')}',
    );
  }
  return b.toString();
}

void main() {
  late Directory dir;
  setUp(
    () async => dir = await Directory.systemTemp.createTemp('tessera_http_'),
  );
  tearDown(() => dir.delete(recursive: true));

  test(
    'reads columns and rows over HTTP, estimates from Content-Length',
    () async {
      final (server, requests) = await serve(csv(2000));
      addTearDown(server.close);
      final source = HttpCsvDataSource(
        Uri.parse('http://${server.address.host}:${server.port}/data.csv'),
        cacheFile: File('${dir.path}/data.csv'),
      );
      expect(await source.columnNames(), ['id', 'name', 'value']);
      final estimate = await source.estimatedRowCount();
      expect(estimate, closeTo(2000, 20));
      // prefix reads leave no cache behind
      expect(source.isCached, isFalse);
      expect(File('${dir.path}/data.csv.part').existsSync(), isFalse);
      expect(requests.first, 'HEAD /data.csv');
    },
  );

  test('a full read caches the file; later reads use the cache', () async {
    final (server, requests) = await serve(csv(500));
    addTearDown(server.close);
    final source = HttpCsvDataSource(
      Uri.parse('http://${server.address.host}:${server.port}/data.csv'),
      cacheFile: File('${dir.path}/data.csv'),
    );
    final result = await loadFacts(source);
    expect(result.facts.rowCount, 500);
    expect(result.facts.valueAt(3, 'value'), 4.5);
    expect(source.isCached, isTrue);
    final gets = requests.where((r) => r.startsWith('GET')).length;
    expect(await source.rows().length, 500);
    expect(
      requests.where((r) => r.startsWith('GET')).length,
      gets,
      reason: 'served from cache',
    );
    // the header line skews the length-based estimate slightly
    expect(await source.estimatedRowCount(), closeTo(500, 5));
    source.clearCache();
    expect(source.isCached, isFalse);
  });

  test(
    'a fresh instance sees the cache (what the import isolate does)',
    () async {
      final (server, requests) = await serve(csv(100));
      addTearDown(server.close);
      final uri = Uri.parse(
        'http://${server.address.host}:${server.port}/data.csv',
      );
      final file = File('${dir.path}/data.csv');
      await HttpCsvDataSource(uri, cacheFile: file).rows().length;
      requests.clear();
      final again = HttpCsvDataSource(uri, cacheFile: file);
      expect(await again.rows().length, 100);
      expect(requests, isEmpty);
      // and it can be sent to an isolate
      final result = await loadFactsInIsolate(
        HttpCsvDataSource(uri, cacheFile: file),
      );
      expect(result.facts.rowCount, 100);
    },
  );

  test('chunked responses have no estimate but still import', () async {
    // More rows than inferSchema samples, or inference alone would read
    // (and cache) the whole file.
    final (server, _) = await serve(csv(3000));
    addTearDown(server.close);
    final source = HttpCsvDataSource(
      Uri.parse('http://${server.address.host}:${server.port}/chunked.csv'),
      cacheFile: File('${dir.path}/chunked.csv'),
    );
    expect(await source.estimatedRowCount(), isNull);
    final reports = <ImportProgress>[];
    final result = await loadFacts(
      source,
      importer: const FactTableImporter(progressEvery: 1000),
      onProgress: (p) {
        reports.add(p);
        return true;
      },
    );
    expect(result.facts.rowCount, 3000);
    expect(reports.map((p) => p.fraction), [null, null, 1.0]);
    // once cached, the length is known
    expect(await source.estimatedRowCount(), closeTo(3000, 10));
  });

  test('HTTP errors surface as exceptions', () async {
    final (server, _) = await serve(csv(10));
    addTearDown(server.close);
    final source = HttpCsvDataSource(
      Uri.parse('http://${server.address.host}:${server.port}/missing.csv'),
      cacheFile: File('${dir.path}/missing.csv'),
    );
    expect(() => source.columnNames(), throwsA(isA<HttpException>()));
    expect(source.isCached, isFalse);
  });

  test('default name comes from the URL', () {
    final s = HttpCsvDataSource(
      Uri.parse('https://example.com/a/b/routes.dat'),
      cacheFile: File('x'),
    );
    expect(s.name, 'routes.dat');
  });
}
