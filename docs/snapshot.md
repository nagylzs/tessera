# Tessera snapshot format (version 1)

A snapshot is a fact table — the imported, typed, columnar data Tessera
pivots over — and optionally a pivot configuration, in one buffer of bytes
that loads back without parsing or type inference. It is what
`TesseraSnapshot.encode` writes and `TesseraSnapshot.decode` reads, and it
is meant to be written by other software too: a server that imports a
large file once and sends the table to clients, a job that materializes a
query result for a Tessera front end. Nothing in it is specific to Dart.

Snapshots are a cache and a transport format, not an interchange format
for other tools; a Tessera client reads every version up to the one it
knows and rejects newer ones.

## Layout

All integers are little-endian. Offsets in the header are relative to the
start of the data area, which begins at the first multiple of 8 at or after
the end of the header. Every section starts at a multiple of 8 within the
data area; the gap between sections is padding (zero bytes recommended).

| Offset | Size | Content |
|---|---|---|
| 0 | 4 | Magic: the ASCII bytes `TSNP`. |
| 4 | 4 | Format version, `uint32`: `1`. |
| 8 | 4 | Header length in bytes, `uint32`. |
| 12 | header length | The header: a UTF-8 JSON object, see below. |
| data area | | Column sections, back to back, each 8-byte aligned. |

## Header

```json
{
  "rows": 1000,
  "schema": { "columns": [ { "name": "region", "type": "text" }, … ] },
  "columns": [ … ],
  "config": { … }
}
```

- `rows`: the number of rows in every column.
- `schema`: the schema the table was imported with, in the JSON form of
  `CubeJson.encodeSchema` (name, type, label, include, format,
  numberSyntax, nullValues per column). Every included column of the
  schema must have an entry in `columns`.
- `columns`: one object per column, in table order:
  - `name`: the column name (unique).
  - `label`: the display label; defaults to `name`.
  - `type`: `text`, `integer`, `number`, `boolean`, `date` or `dateTime`.
  - for `integer`, `number`, `date` and `dateTime`: `data`, a section
    descriptor with `encoding` `f64`.
  - for `boolean`: `data`, a section descriptor with `encoding` `u8`.
  - for `text`: `dictionary` (a section descriptor with an additional
    `count`, the number of strings) and `codes` (a section descriptor
    with `encoding` `i8`, `i16` or `i32`).
- `config` (optional): a pivot configuration in the JSON form of
  `CubeJson.encodeConfig` — the spec, both expansion states and a schema,
  with its own `version`.

A section descriptor is `{"encoding": …, "offset": …, "length": …}`:
`offset` is the section's position in the data area (a multiple of 8),
`length` its size in bytes. Lengths must match exactly: `rows × 8` for
`f64`, `rows × 1` for `u8` and `i8`, `rows × 2` for `i16`, `rows × 4` for
`i32`.

## Sections

- **`f64`**: `rows` IEEE 754 binary64 values. Numbers are stored as
  doubles (integers exactly, up to 2⁵³); dates and date-times as
  milliseconds since 1970-01-01T00:00:00Z. A missing value is NaN (any
  NaN).
- **`u8`**: `rows` bytes; `0` = false, `1` = true, `2` = missing. Other
  values are rejected.
- **dictionary**: `count` `uint32` byte lengths, then the strings' UTF-8
  bytes back to back in the same order. Strings are the distinct non-null
  values of the column; order is free (Tessera writes first-occurrence
  order).
- **`i8` / `i16` / `i32`**: `rows` signed integers of 1, 2 or 4 bytes: the
  index into the dictionary, or `-1` for a missing value. Any other value
  outside `-1 … count − 1` is rejected. A writer should pick the narrowest
  width that holds `count − 1`.

## Reading rules

A reader checks the magic, refuses a version above the one it supports,
checks that every section lies inside the buffer, is 8-byte aligned and has
the exact length its encoding requires, that every text code is in range
and every boolean is 0, 1 or 2, and that the dictionary is valid UTF-8.
Anything else is a malformed snapshot (`FormatException` in Dart).

## Notes for writers

- Compression is left to the transport or the file layer: an HTTP response
  with `Content-Encoding: gzip`, a `.gz` file. Columnar data compresses
  well.
- The whole buffer is held in memory by the reader; a snapshot of 2 M rows
  × 11 columns is around 100 MB uncompressed.
- Extra keys in the header are ignored by readers, so a writer may add
  its own metadata (source name, timestamps) without breaking anything.
