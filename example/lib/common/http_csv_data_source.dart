import 'dart:io';

import 'package:tessera/tessera.dart';

/// A [DataSource] that streams a CSV file over HTTP — an example of
/// implementing the interface on top of [CsvDataSource].
///
/// * Every iteration opens a fresh GET. Partial reads (schema inference,
///   row estimates) cancel the request early, so only the needed prefix is
///   downloaded.
/// * The first iteration that runs to the end writes the bytes to
///   [cacheFile]; later iterations read the cache instead, so re-imports
///   (after editing the schema) are free. `.part` files are removed when a
///   download is abandoned.
/// * [estimatedRowCount] uses `Content-Length` when the server sends one
///   (GitHub does; Socrata-style exports are chunked and don't, in which
///   case progress falls back to a plain row counter).
///
/// Holds only a [Uri], a [File] and plain values, so it can be sent to an
/// import isolate; the [HttpClient] lives inside each request.
final class HttpCsvDataSource implements DataSource {
  HttpCsvDataSource(
    this.uri, {
    required this.cacheFile,
    this.options = const CsvOptions(),
    String? name,
  }) : name =
           name ??
           uri.pathSegments.lastWhere(
             (s) => s.isNotEmpty,
             orElse: () => uri.host,
           );

  final Uri uri;
  final File cacheFile;
  final CsvOptions options;

  @override
  final String name;

  @override
  Schema? get declaredSchema => null;

  CsvDataSource? _cached;
  CsvDataSource? _network;
  int? _contentLength;

  bool get isCached => cacheFile.existsSync();

  /// The underlying CSV source: the cache file once it is complete,
  /// otherwise the network with the `Content-Length` (if any) as length.
  Future<CsvDataSource> _inner() async {
    if (isCached) {
      return _cached ??= CsvDataSource.fromBytes(
        cacheFile.openRead,
        name: name,
        options: options,
        length: cacheFile.lengthSync(),
      );
    }
    final network = _network;
    if (network != null) return network;
    _contentLength ??= await _fetchContentLength();
    return _network = CsvDataSource.fromBytes(
      _download,
      name: name,
      options: options,
      length: _contentLength,
    );
  }

  Future<int?> _fetchContentLength() async {
    final client = HttpClient();
    try {
      final request = await client.headUrl(uri);
      final response = await request.close();
      await response.drain<void>();
      return response.contentLength > 0 ? response.contentLength : null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// One GET, teed into `cacheFile.part`; promoted to [cacheFile] only if
  /// the stream was consumed to the end.
  Stream<List<int>> _download() async* {
    final client = HttpClient();
    final part = File('${cacheFile.path}.part');
    var complete = false;
    IOSink? sink;
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode}', uri: uri);
      }
      await part.parent.create(recursive: true);
      sink = part.openWrite();
      await for (final chunk in response) {
        sink.add(chunk);
        yield chunk;
      }
      complete = true;
    } finally {
      await sink?.close();
      if (complete) {
        await part.rename(cacheFile.path);
      } else if (part.existsSync()) {
        part.deleteSync();
      }
      client.close(force: true);
    }
  }

  @override
  Future<List<String>> columnNames() async => (await _inner()).columnNames();

  @override
  Stream<SourceRow> rows() async* {
    yield* (await _inner()).rows();
  }

  @override
  Future<int?> estimatedRowCount() async =>
      (await _inner()).estimatedRowCount();

  /// Removes the cached download.
  void clearCache() {
    if (isCached) cacheFile.deleteSync();
    _cached = null;
  }
}
