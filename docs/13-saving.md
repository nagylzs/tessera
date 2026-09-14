# 13. Saving and restoring

Two things are worth persisting: the pivot *configuration* (what the
user built) and the *data* (what took time to import). They have
different formats because they have different lives.

## The configuration: CubeJson

`CubeConfig` bundles a `CubeSpec`, both `ExpansionState`s and the
`Schema`; `CubeJson` turns it into plain JSON data and back:

```dart
// save
final config = CubeConfig.of(controller.cube, schema: editedSchema);
final text = jsonEncode(CubeJson.standard.encodeConfig(config));

// restore, over the same source
final restored = CubeJson.standard.decodeConfig(jsonDecode(text) as Map<String, Object?>);
final facts = (await loadFacts(source, schema: restored.schema)).facts;
controller.cube = restored.toCube(facts);
```

Every built-in dimension, measure, aggregate and filter has a JSON form;
expressions are stored as their source text, dates as `{"date": "…"}`,
expansion paths as lists of values positional against their axis, sort
keys as self-contained paths. A `version` on the config allows later
migrations. Malformed input is a `FormatException`.

Two things to know:

- The fact table's own schema holds the *imported* columns only, with the
  types the import settled on. If your app lets the user exclude columns
  or edit types, pass that edited schema to `CubeConfig.of` so the
  exclusions are kept.
- A `PredicateFilter`, a `MappedDimension`, a custom aggregate and a
  `ColumnSpec.parser` are Dart functions. The first three throw
  `UnsupportedError` unless you register a `JsonAdapter` for them; the
  parser is dropped silently.

```dart
final codec = CubeJson(
  aggregates: [MyRangeAdapter()],          // JsonAdapter<Aggregate>: type, encode, decode
  functions: myFunctions,                  // reaches every decoded expression
);
```

`CubeJson` also encodes and decodes each part on its own — `encodeSpec`,
`encodeFilter`, `encodeExpansion(state, axis)`, `encodeSchema`, … — for
apps that store them separately.

## The data: TesseraSnapshot

Reopening a big file means parsing and importing it again — about 8
seconds for two million rows. A snapshot is the imported fact table
written as bytes and read back in a copy: no parsing, no inference,
under a tenth of a second for the same data.

```dart
final bytes = const TesseraSnapshot().encode(facts, config: CubeConfig.of(cube));
// … later, or on another machine
final contents = const TesseraSnapshot().decode(bytes);
controller.cube = contents.config!.toCube(contents.facts);
```

The format is a JSON header followed by the raw little-endian column
arrays, documented in [snapshot.md](snapshot.md) so that other software
can write it — a server that imports once and sends the table to its
clients, a job that materializes a query for a Tessera front end.
Nothing is compressed; leave that to the transport (`Content-Encoding:
gzip`) or the file layer. `decode` validates every section and rejects
a snapshot from a newer format version with a `FormatException`.

Treat snapshots as a cache or a transport, not as an archive: they are
tied to the engine's storage decisions and are rebuilt from the source
when in doubt.
