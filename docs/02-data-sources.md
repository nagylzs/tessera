# 2. Data sources

A `DataSource` is anything that can name its columns and yield its rows,
more than once. That is the whole contract:

```dart
abstract interface class DataSource {
  String get name;                       // shown to the user, e.g. the file name
  Schema? get declaredSchema;            // types known up front, or null to infer
  Future<List<String>> columnNames();
  Stream<SourceRow> rows();              // SourceRow = List<Object?>, one per record
  Future<int?> estimatedRowCount();      // for progress bars; null when unknown
}
```

Rows are re-read: once by schema inference (a prefix only) and once by
the import. A source must therefore be able to open its data again, which
is why the CSV constructors take bytes or a callback rather than a live
stream.

## CSV

```dart
CsvDataSource.fromString(text, name: 'sales.csv');
CsvDataSource.fromData(bytes, name: 'sales.csv');            // Uint8List; sendable to an isolate
CsvDataSource.fromBytes(file.openRead, name: 'sales.csv',   // a callback that opens a byte stream
    length: file.lengthSync());                               // length enables the row estimate
```

`CsvOptions` covers the usual variations: `delimiter` (`'\t'` for TSV,
`';'` for European exports), `quote`, `hasHeader` (when `false` columns
are named `column1`, `column2`, …), `skipLeadingLines` for files with a
title block, `trimCells`. The parser is streaming and handles quoted
fields with embedded delimiters, quotes and newlines, a byte order mark,
and both line endings.

Values arrive as strings; the schema decides what they become
([next chapter](03-schema.md)).

## Lists

`ListDataSource` wraps rows you already have in memory — from a database
query, a JSON document, a test:

```dart
final source = ListDataSource(
  columns: ['region', 'country', 'date', 'qty'],
  rows: [
    ['Europe', 'Germany', DateTime.utc(2024, 1, 5), 1],
    ['Europe', 'Hungary', '2024-03-05', 2],          // strings are parsed like CSV cells
    ['Asia', null, null, 5],                         // null is a missing value
  ],
  declaredSchema: Schema([                           // optional: skip inference
    const ColumnSpec(name: 'region', type: ColumnType.text),
    const ColumnSpec(name: 'country', type: ColumnType.text),
    const ColumnSpec(name: 'date', type: ColumnType.date),
    const ColumnSpec(name: 'qty', type: ColumnType.integer),
  ]),
);
```

Typed values (`int`, `double`, `bool`, `DateTime`) are taken as they are;
strings go through the same parsers as CSV cells, so a mixed list works.

## Excel and OpenDocument sheets

`tessera_xlsx` and `tessera_ods` read one worksheet as rows, with typed
cells: numbers stay numbers, dates come out as `DateTime` (the xlsx reader
recognizes Excel's date styles and the 1904 date system), booleans as
`bool`.

```dart
import 'package:tessera_xlsx/tessera_xlsx.dart';

final source = XlsxDataSource.fromData(bytes, name: 'sales.xlsx',
    options: const XlsxOptions(sheet: 'Data', skipRows: 2));
```

`XlsxOptions` / `OdsOptions`: `sheet` (name; `null` = the first one),
`hasHeader` (when `false` columns are named `A`, `B`, …), `skipRows` for
title rows above the header (blank rows count), `trim`. Both packages are
pure Dart, built on `archive` and `xml`, and both also *write* sheets
([export chapter](11-export.md)). The whole decompressed sheet XML is held
in memory while reading, so a 500 MB sheet is not a good idea; CSV
streams.

## Your own source

Implement `DataSource` when the data lives somewhere else. The demo app's
`HttpCsvDataSource` (`example/lib/common/http_csv_data_source.dart`)
streams a CSV file from a URL, cancels the download early when only a
prefix is read (schema inference), caches the file on disk after the
first full pass, and answers `estimatedRowCount` from the `Content-Length`
header. It holds only a `Uri` and a `File`, so it can be sent to an import
isolate.

Things to get right:

- `rows()` must be callable more than once and return the same data.
- Yield `null` for missing values, not empty strings — or leave the
  strings in and let `ColumnSpec.nullValues` handle them.
- If the source is going to be imported in an isolate
  ([large data](14-large-data.md)), it must be sendable: plain fields,
  no open sockets or closures capturing widget state.

## Snapshots

A `TesseraSnapshot` is not a `DataSource` but a shortcut past sources
altogether: an imported fact table written as bytes and read back in a
copy, with no parsing and no inference. It is what a server hands to a
client, or what an app writes next to a big file so the second open is
instant. See [saving and restoring](13-saving.md).
