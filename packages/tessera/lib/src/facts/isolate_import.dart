import 'dart:async';
import 'dart:isolate';

import '../schema/schema.dart';
import '../source/data_source.dart';
import '../source/schema_inference.dart';
import 'importer.dart';

/// `true` when compiled for the web, where isolates are unavailable.
const _isWeb = bool.fromEnvironment('dart.library.js_interop');

/// Like [loadFacts], but does the work in a separate isolate so the UI
/// stays responsive, forwarding [onProgress] reports to the caller.
///
/// The [source] is sent to the isolate, so it must be sendable: sources
/// built on plain data or a `File` (e.g. `CsvDataSource.fromData(bytes)`
/// or `CsvDataSource.fromBytes(file.openRead, length: file.lengthSync())`)
/// are; sources wrapping a live stream, socket or database connection are
/// not. Custom [ColumnSpec.parser] closures must be sendable too.
///
/// Beware that a Dart closure captures its whole enclosing scope: a
/// callback written inside a `State` method or next to a `Future` variable
/// makes the source unsendable ("object is unsendable - _Future"). Create
/// such callbacks in a static or top-level function, or use the
/// closure-free constructors.
///
/// Returning `false` from [onProgress] cancels the import; the returned
/// future then completes with [ImportCancelled]. On the web this falls back
/// to [loadFacts] in the calling isolate.
Future<ImportResult> loadFactsInIsolate(
  DataSource source, {
  Schema? schema,
  InferenceOptions inference = const InferenceOptions(),
  FactTableImporter importer = const FactTableImporter(),
  ImportProgressCallback? onProgress,
}) async {
  if (_isWeb) {
    return loadFacts(
      source,
      schema: schema,
      inference: inference,
      importer: importer,
      onProgress: onProgress,
    );
  }
  final port = ReceivePort();
  SendPort? cancelPort;
  var cancelled = false;
  final subscription = port.listen((message) {
    if (message is SendPort) {
      cancelPort = message;
      if (cancelled) message.send(null);
    } else if (message is ImportProgress) {
      if (onProgress != null && !cancelled && !onProgress(message)) {
        cancelled = true;
        cancelPort?.send(null);
      }
    }
  });
  try {
    return await _runWorker(source, schema, inference, importer, port.sendPort);
  } finally {
    await subscription.cancel();
    port.close();
  }
}

/// Spawns the worker. Kept in its own function so the closure sent to the
/// isolate captures only these (sendable) parameters — not the caller's
/// ports and callback, which would share its scope otherwise.
Future<ImportResult> _runWorker(
  DataSource source,
  Schema? schema,
  InferenceOptions inference,
  FactTableImporter importer,
  SendPort sendPort,
) => Isolate.run(() async {
  final cancelPort = ReceivePort();
  var cancelled = false;
  cancelPort.listen((_) => cancelled = true);
  sendPort.send(cancelPort.sendPort);
  try {
    return await loadFacts(
      source,
      schema: schema,
      inference: inference,
      importer: importer,
      onProgress: (progress) {
        sendPort.send(progress);
        return !cancelled;
      },
    );
  } finally {
    cancelPort.close();
  }
});
