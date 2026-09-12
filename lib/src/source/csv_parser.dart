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
Stream<List<String>> parseCsv(
  Stream<String> chunks,
  CsvOptions options,
) async* {
  final delimiter = options.delimiter.codeUnitAt(0);
  final quote = options.quote.codeUnitAt(0);
  const cr = 0x0D, lf = 0x0A, bom = 0xFEFF;

  var linesToSkip = options.skipLeadingLines;
  var atStart = true;
  var pendingCr = false; // saw '\r'; a following '\n' belongs to it
  var inQuotes = false;
  var afterQuote =
      false; // just saw a quote while inQuotes: closing or escaped?
  var fieldQuoted = false; // current field started with a quote
  var recordQuoted = false; // any field of the record was quoted
  final field = StringBuffer();
  var record = <String>[];

  void endField() {
    var value = field.toString();
    if (options.trimCells && !fieldQuoted) value = value.trim();
    record.add(value);
    field.clear();
    fieldQuoted = false;
  }

  List<String>? endRecord() {
    endField();
    final done = record;
    final blank = done.length == 1 && done[0].isEmpty && !recordQuoted;
    record = <String>[];
    recordQuoted = false;
    return blank ? null : done;
  }

  await for (final chunk in chunks) {
    final n = chunk.length;
    var i = 0;
    var runStart = 0; // start of the pending run of ordinary characters

    while (i < n) {
      final c = chunk.codeUnitAt(i);

      if (atStart) {
        atStart = false;
        if (c == bom) {
          i++;
          runStart = i;
          continue;
        }
      }

      if (linesToSkip > 0) {
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
        i++;
        runStart = i;
        continue;
      }

      if (pendingCr) {
        pendingCr = false;
        if (c == lf) {
          i++;
          runStart = i;
          continue;
        }
      }

      final special = c == delimiter || c == quote || c == cr || c == lf;
      if (!special) {
        afterQuote = false;
        i++;
        continue;
      }

      if (i > runStart) field.write(chunk.substring(runStart, i));
      runStart = i + 1;

      if (inQuotes) {
        if (c == quote) {
          inQuotes = false;
          afterQuote = true;
        } else {
          field.writeCharCode(c);
        }
      } else if (afterQuote && c == quote) {
        // Escaped quote inside a quoted field.
        field.writeCharCode(quote);
        inQuotes = true;
        afterQuote = false;
      } else {
        afterQuote = false;
        if (c == delimiter) {
          endField();
        } else if (c == cr || c == lf) {
          pendingCr = c == cr;
          final done = endRecord();
          if (done != null) yield done;
        } else if (field.isEmpty && !fieldQuoted) {
          inQuotes = true;
          fieldQuoted = true;
          recordQuoted = true;
        } else {
          field.writeCharCode(c);
        }
      }
      i++;
    }
    if (i > runStart) field.write(chunk.substring(runStart, i));
  }

  if (field.isNotEmpty || record.isNotEmpty || fieldQuoted) {
    final done = endRecord();
    if (done != null) yield done;
  }
}
