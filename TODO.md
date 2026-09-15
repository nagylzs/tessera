# TODO

Reset 2026-09-15 after the 0.2.1 release: everything from the
pre-publish review is done (the history is in git and the CHANGELOGs).
Tick items here as they are done; a feature commit also adds its bullet
under `## Unreleased` in the affected package's CHANGELOG.

## Example app

- [ ] Save and load a pivot layout: `CubeConfig.of(cube, schema:)` →
      `CubeJson.encodeConfig` to a `.json` file through the existing
      `FilePicker.saveFile` path, and a "Load layout…" action that reads
      one back (`decodeConfig`, `toCube(facts)`), prunes members whose
      columns are missing (reuse `_prune`) and restores the expansion
      state. Show both in the workbench's menu so the JSON chapter of the
      guide has a demo to point at.
- [ ] Open a snapshot file (`.tsnp`): a data source hook in the workbench
      that loads `TesseraSnapshot.decode` output (facts + optional
      config) instead of importing, and a "Save snapshot…" counterpart.

## Engine

- [ ] Register `application/vnd.tessera.snapshot` with IANA once Tessera
      Studio is released (the form asks for an application that uses the
      type): https://www.iana.org/form/media-types — vendor tree, no RFC
      needed; specification = `docs/snapshot.md`, encoding binary, magic
      `TSNP` at offset 0, extension `.tsnp`. Then a shared-mime-info
      entry (freedesktop) so Linux desktops detect it by magic.
- [ ] Snapshot: narrower number encodings (int32 for integral columns,
      day numbers for dates) if size ever matters; keep version 1
      readable.
- [ ] Decide whether a database / lazy server-side source is in scope at
      all. Current position: no, tessera is in-memory; the snapshot format
      is the server-to-client path.

## Visibility

- [ ] Announce 0.2.x: a short post with the screenshot and the two-minute
      example (Flutter subreddit, Flutter Weekly, Dart community
      channels); answer the first issues quickly.
- [ ] Re-check the pub.dev score of `tessera` and `tessera_flutter` once
      0.2.1 is analyzed (the exporters are at 160/160).

## Out of scope, by decision (so nobody re-opens them)

- Median and percentiles: cells never store row lists.
- Cell editing and spreadsheet features.
- A bundled chart widget: the engine produces series, the app draws.
