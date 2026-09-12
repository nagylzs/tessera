import 'csv_data_source.dart';

/// Incremental CSV tokenizer: turns a stream of text chunks into records.
///
/// Handles RFC 4180 quoting (`"a ""b"", c"`, newlines inside quotes), any of
/// `\n`, `\r\n` or `\r` as record separators, a leading UTF‑8 BOM, and
/// chunk boundaries anywhere — including inside a quoted field or a `\r\n`
/// pair. It is lenient about malformed input: a quote inside an unquoted
/// field is literal, text after a closing quote is appended, and an
/// unterminated quote is closed at end of input.
///
/// Blank records (a single empty unquoted field) are skipped, as are the
/// first [CsvOptions.skipLeadingLines] lines.
///
/// If [stats] is given it is updated as records are yielded.
///
/// Performance: the common case — an unquoted field inside one chunk — is
/// a single `substring`; the [StringBuffer] is only used for fields that
/// contain quotes or span chunks.
Stream<List<String>> parseCsv(
  Stream<String> chunks,
  CsvOptions options, {
  CsvParseStats? stats,
}) async* {
  final delimiter = options.delimiter.codeUnitAt(0);
  final quote = options.quote.codeUnitAt(0);
  const cr = 0x0D, lf = 0x0A, bom = 0xFEFF;
  final trim = options.trimCells;

  var linesToSkip = options.skipLeadingLines;
  var atStart = true;
  var pendingCr = false; // saw '\r'; a following '\n' belongs to it
  var inQuotes = false;
  var afterQuote =
      false; // just saw a quote while inQuotes: closing or escaped?
  var fieldQuoted = false; // current field started with a quote
  var recordQuoted = false; // any field of the record was quoted
  final field = StringBuffer(); // only for quoted or chunk-spanning fields
  var record = <String>[];
  var consumed = 0; // characters in the chunks fully processed so far

  void endField(String value) {
    record.add(trim && !fieldQuoted ? value.trim() : value);
    fieldQuoted = false;
  }

  List<String>? endRecord() {
    final done = record;
    final blank = done.length == 1 && done[0].isEmpty && !recordQuoted;
    record = <String>[];
    recordQuoted = false;
    return blank ? null : done;
  }

  /// The field text ending at [end]: the pending run, plus whatever the
  /// buffer holds from quotes or an earlier chunk.
  String take(String chunk, int start, int end) {
    if (field.isEmpty) return chunk.substring(start, end);
    if (end > start) field.write(chunk.substring(start, end));
    final value = field.toString();
    field.clear();
    return value;
  }

  await for (final chunk in chunks) {
    final n = chunk.length;
    var i = 0;

    if (atStart) {
      atStart = false;
      if (n > 0 && chunk.codeUnitAt(0) == bom) i = 1;
    }
    while (linesToSkip > 0 && i < n) {
      final c = chunk.codeUnitAt(i++);
      if (c == lf) {
        if (pendingCr) {
          pendingCr = false;
        } else {
          linesToSkip--;
        }
      } else if (c == cr) {
        linesToSkip--;
        pendingCr = true;
      } else {
        pendingCr = false;
      }
    }
    if (pendingCr && i < n) {
      pendingCr = false;
      if (chunk.codeUnitAt(i) == lf) i++;
    }

    var runStart = i; // start of the pending run of ordinary characters
    while (i < n) {
      final c = chunk.codeUnitAt(i);
      if (c != delimiter && c != quote && c != cr && c != lf) {
        i++;
        continue;
      }
      // A closing quote only "counts" if nothing ordinary followed it.
      if (afterQuote && i != runStart) afterQuote = false;

      if (!inQuotes && !afterQuote && c != quote) {
        // Separator ending an unquoted field: the common case.
        endField(take(chunk, runStart, i));
        runStart = i + 1;
        if (c != delimiter) {
          if (c == cr) {
            if (i + 1 < n) {
              if (chunk.codeUnitAt(i + 1) == lf) {
                i++;
                runStart = i + 1;
              }
            } else {
              pendingCr = true;
            }
          }
          final done = endRecord();
          if (done != null) {
            stats?.record(consumed + i + 1);
            yield done;
          }
        }
        i++;
        continue;
      }

      if (inQuotes) {
        if (i > runStart) field.write(chunk.substring(runStart, i));
        if (c == quote) {
          inQuotes = false;
          afterQuote = true;
        } else {
          field.writeCharCode(c);
        }
      } else if (afterQuote) {
        afterQuote = false;
        if (c == quote) {
          // Escaped quote inside a quoted field.
          field.writeCharCode(quote);
          inQuotes = true;
        } else {
          // Separator right after the closing quote.
          endField(take(chunk, runStart, i));
          if (c != delimiter) {
            if (c == cr) {
              if (i + 1 < n) {
                if (chunk.codeUnitAt(i + 1) == lf) i++;
              } else {
                pendingCr = true;
              }
            }
            final done = endRecord();
            if (done != null) {
              stats?.record(consumed + i + 1);
              yield done;
            }
          }
        }
      } else if (field.isEmpty && i == runStart && !fieldQuoted) {
        // Opening quote at the start of a field.
        inQuotes = true;
        fieldQuoted = true;
        recordQuoted = true;
      } else {
        // A quote in the middle of an unquoted field is literal.
        if (i > runStart) field.write(chunk.substring(runStart, i));
        field.writeCharCode(c);
      }
      i++;
      runStart = i;
    }
    if (i > runStart) field.write(chunk.substring(runStart, i));
    consumed += n;
  }

  if (field.isNotEmpty || record.isNotEmpty || fieldQuoted) {
    endField(field.toString());
    field.clear();
    final done = endRecord();
    if (done != null) {
      stats?.record(consumed);
      yield done;
    }
  }
}

/// Running counters of a [parseCsv] run.
final class CsvParseStats {
  /// Records yielded so far.
  int records = 0;

  /// Characters of input consumed through the end of the last record.
  int characters = 0;

  void record(int charactersConsumed) {
    records++;
    characters = charactersConsumed;
  }
}
