# TODO before publishing to pub.dev

Notes from the pre-publish review (2026-09-13). Not in a hurry; work
through these in order, then publish.

## API decisions (cheap now, expensive after the first release)

- [x] `CubeView` shows one aggregate per cell while every exporter renders
      all selected aggregates side by side. Decided: several aggregates in
      the widget (`aggregates`, one column per aggregate under each column
      entry, `AggregateEditor` selection is a set).
- [x] Exporters return `String` (csv, html, svg), `Uint8List` (xlsx, ods)
      or `Future<Uint8List>` (pdf, forced by `package:pdf`). Keep, but say
      so in each README.

## Small fixes

- [x] Dartdoc: `[spec.name]` in `Schema` (`packages/tessera/lib/src/schema/schema.dart`)
      is not a resolvable reference; write it as `` `spec.name` ``.
- [x] `example/main.dart` for the engine (`packages/tessera`), the only
      package without an example; a CSV → cube → CSV export round trip.
- [x] Versions 0.0.1 → 0.1.0 in every package (and the inter-package
      constraints `tessera: ^0.1.0` etc.).
- [x] `topics:` in every pubspec (pivot-table, olap, aggregation, csv,
      xlsx, ods, html, svg, pdf, export as they apply).
- [x] A screenshot of `CubeView` in the `tessera_flutter` README (pub.dev
      resolves relative image links against `repository`) and
      `screenshots:` in its pubspec.
- [x] Root README: one screenshot, the icon is already there.

## Repository and publishing

- [x] Push the repository to `github.com/nagylzs/tessera` first; every
      pubspec's `repository` points there and pub.dev verifies the link.
- [x] Fix the GitHub repository description: it promises TSV, Excel and
      JSONL input. TSV works through `CsvOptions` (tab delimiter), Excel
      through `tessera_xlsx`, JSONL does not exist (see below).
- [x] Optional: a short, neutral "Alternatives" section in the root README
      (what tessera is for, what it deliberately is not: charts, editing,
      server-side data) with links to the packages that cover those; no
      metrics or judgements, so it cannot go stale.
- [x] Optional: `dart pub global activate pana` and run it on each package
      for the score pub.dev will show.
- [x] Publish order: `tessera`, then `tessera_xlsx`, `tessera_ods`,
      `tessera_html`, `tessera_svg`, `tessera_pdf`, then `tessera_flutter`
      (pub checks that dependencies exist). Run the dry runs once more
      right before; versions cannot be deleted, only retracted within
      seven days. (0.1.0 of all seven published 2026-09-14/15, under the
      `nagylzs.eu` publisher.)

## User guide (repository only, not uploaded)

- [ ] `docs/` at the repository root: a guide for new users in logical
      order, more detailed than the READMEs (data sources and schema
      inference, the fact table, dimensions and measures, building a cube,
      expansion and sorting, filters, the widgets, theming, export
      formats, localization, large data). Link it from every README.

## Features users will ask for next (after the first release)

- [ ] A filter editor widget: the engine has the filter model
      (`FactFilter`, `ValueFilter`, `AndFilter`, …) but no UI for it.
- [ ] Saving a pivot configuration: JSON for `CubeSpec`, `ExpansionState`
      and schema overrides, so an app can persist and restore a layout.
- [ ] Calculated aggregates: percent of row/column/grand total, difference
      from a base value.
- [ ] More data sources: JSON (array of objects) and JSONL, the formats
      every competitor reads; `ListDataSource` covers programmatic data
      already. A database/server-side (lazy) source is a bigger design
      question; decide whether it is in scope at all.
- [ ] Charts: decide and document. The commercial pivots and om_data_grid
      pair the table with charts; tessera probably stays a table and
      leaves charts to the app (a `CubeLayout` → chart series helper would
      be the cheap middle ground).
- [ ] Trust signals after publishing: a screenshot-led README, the user
      guide, a CHANGELOG discipline and an issue template; the popular
      grids win on track record for a while.
