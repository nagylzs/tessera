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

- [x] `docs/` at the repository root: a guide for new users in logical
      order, more detailed than the READMEs (data sources and schema
      inference, the fact table, dimensions and measures, building a cube,
      expansion and sorting, filters, the widgets, theming, export
      formats, localization, large data). Link it from every README.
      Done 2026-09-14: 14 chapters + the snapshot spec, 33 screenshots
      in `docs/images/` (English UI; Hungarian once, for the
      localization chapter), linked from the root README and every
      package README.

## Expression language (decided 2026-09-14, do before the filter editor and calculated aggregates)

Surveyed pub.dev for an expression evaluator (expressions, cel, rumil_expressions,
quds_formula_parser, worksheet_formula, eval_ex, petitparser, sqlparser, dart_eval,
hetu_script, jsonata_dart, jsonlogic, sqlite3, duckdb): nothing fits (no
null-as-group semantics, no DateTime, runtime-only typing, no error positions,
JS-flavoured syntax, or heavy/platform dependencies). Decided: an own small
language in the engine, dependency-free, in-memory like the rest. The heavy
backends (sqlite3/duckdb) were rejected: tessera stays in-memory, and copying
the facts into a database only pays off if the whole cube moved there.

- [x] Grammar and parser (`expr/` in `packages/tessera`): a hand-written
      Pratt parser (no petitparser). SQL/Excel-flavoured syntax for
      spreadsheet users: `and`/`or`/`not`, `=`, `<>`, `<`, `<=`, `>`, `>=`,
      `+ - * / %`, unary minus, `in (...)`, `between`, `is empty` / `is not
      empty`, `if(cond, a, b)`, string/number/boolean/date literals (date as
      `#2024-01-31#` or `date("2024-01-31")`), function calls, parentheses.
      Column references by name; names with spaces or non-ASCII are quoted
      (`[unit price]`). Function names case-insensitive. The stored form is
      locale-neutral (`.` decimal point, English function names); the editor
      may display localized. Parse errors carry source positions (offset +
      length) and are localizable messages via `TesseraStrings`.
- [x] Static typing: a checker resolves column references against the
      `Schema` / `FactTable` and infers a type for every node (number, text,
      boolean, date; all nullable) before anything runs, so the editor can
      validate on every keystroke and highlight the error. Type errors have
      positions like parse errors. Booleans and numbers do not mix.
- [x] Null semantics: three-valued like SQL. Arithmetic and comparison with
      a null operand yield null; `and`/`or` follow SQL truth tables; a null
      filter result means the fact is excluded; `is empty` / `coalesce` are
      the way to test and default. `=` on null is null, matching "(empty)"
      is done with `is empty`, so a null dimension value stays a group.
- [x] Compilation to typed closures over columns: the checker's typed AST is
      compiled to closures that read the `FactTableImpl` storage directly
      (`Float64List` for numbers/dates with NaN = null, `Int32List` codes +
      dictionary for text, `Uint8List` for booleans), never through
      `valueAt`/`Map` contexts, so evaluating a row allocates nothing. Number
      expressions compile to `double Function(int row)`, boolean ones to a
      three-valued result, text ones compare dictionary codes when both sides
      are columns. Parse once, evaluate per row; cost is paid once per cube
      build because the filtered row list is cached and calculated measures
      are materialized (below).
- [x] Built-in functions (small, fixed set): `abs`, `round(x, n)`, `floor`,
      `ceil`, `min`, `max`, `coalesce`; `len`, `lower`, `upper`, `trim`,
      `left`, `right`, `contains`, `startswith`, `endswith`, `concat`;
      `year`, `month`, `day`, `quarter`, `weekday`, `isoweek` (reuse
      `DatePart`), `date`, `today`; `if`, `isempty`. No loops, recursion or
      I/O anywhere in the language (user input must be safe by construction).
- [x] App-supplied functions: a `FunctionRegistry` where an application
      registers a name, parameter types, return type and a Dart closure;
      the checker and compiler treat them like built-ins. Passed to the
      parser/checker explicitly, no global state.
- [x] Plug points in the engine (breaking, do while 0.x): `ExpressionFilter`
      (a `FactFilter` member holding the source text, compiled lazily, equal
      by text); `Measure` becomes sealed with `ColumnMeasure` and
      `ExpressionMeasure` (materialized once into a `Float64List` on first
      use, cached per `FactTable`, then aggregated like any measure);
      `ExpressionDimension` (group by a text/number/date/boolean expression,
      e.g. `if(total > 100, "big", "small")`), materialized the same way;
      cell-level formulas over aggregate results (`sum(total) /
      sum(quantity)`) as a `DerivedAggregate` computed after accumulation,
      so `Aggregate` grows a variant without an accumulator. The same parser
      and checker serve all of them; only the variable context differs
      (fact row vs. the cell's aggregate results).
- [x] Structured filters independent of the language: add serializable
      `FactFilter` members (`CompareFilter` column/op/value, `RangeFilter`,
      `TextFilter` contains/starts/ends, `EmptyFilter`) so the filter editor's
      builder UI (field, operator, value, and/or groups) and the saved
      configuration work without the expression text; the expression is the
      power-user escape hatch and can be converted from the structured tree.
- [x] Layout-relative calculations ("percent of row/column/grand total",
      "difference from base") are NOT expressions: declarative wrappers over
      the layout (`ShowValuesAs`-style), since they need the parent/sibling/base
      cell, not a row or a cell. Done 2026-09-14: `LayoutAggregate` +
      `percentOf`, `differenceFrom`, `percentDifferenceFrom`,
      `runningTotal`, `rank`; localized labels; JSON forms. UI done the
      same day: "Show values as" on the aggregate chips (`ValueDisplay`).
- [x] Tests: parser (positions, precedence, quoting), checker (every type
      rule and error), null truth tables, closure compiler vs. a naive
      interpreter on `sales.csv`, and a benchmark on the 2 M-row set
      (`example/tool/bench.dart`) to confirm the once-per-build cost.
- [x] Docs: a chapter in the user guide with the grammar, the function list
      and the null rules (`docs/08-expressions.md`); the `tessera`
      README has an "Expressions" section, `tessera_flutter`'s
      mentions the filter editor.
- [x] Localized error messages: `ExpressionError` carries `kind`,
      `arguments` and an English `message`; add
      `TesseraStrings.expressionError(ExpressionError)` with the 14
      translations (decided 2026-09-14 to do this after the language).
      Done 2026-09-14 with the filter editor.
- [x] Decided 2026-09-14: text comparisons are case-sensitive (`lower()`
      for the other behaviour), dates support `date ± days` and
      `date - date`; keywords and function names are case-insensitive,
      column names are not; `==` / `!=` are accepted as aliases.

## Features users will ask for next (after the first release)

- [x] Snapshot format (decided and done 2026-09-14): `TesseraSnapshot`
      encodes a fact table plus an optional `CubeConfig` as bytes (JSON
      header + raw little-endian columns, spec in `docs/snapshot.md`); a
      cache for reopening, and a server-to-client transport that offloads
      parsing and import. Uncompressed by design (HTTP content encoding /
      gzip at the file layer). Follow-ups: a `SnapshotDataSource`-style
      hook in the example app (load a `.tsnp` file), and narrower number
      encodings (int32, day numbers) if size matters.

- [x] A filter editor widget: the engine has the filter model
      (`FactFilter`, `ValueFilter`, `AndFilter`, …) but no UI for it.
      Builds on the structured filters and `ExpressionFilter` above: a
      builder (field, operator, value, and/or groups) plus an expression text
      field with live validation from the checker. Done 2026-09-14:
      `FilterEditor` / `showFilterEditor` in `tessera_flutter`
      (read-only rows for `PredicateFilter`s, as decided); wired into the
      example workbench.
- [x] Saving a pivot configuration: JSON for `CubeSpec`, `ExpansionState`
      and schema overrides, so an app can persist and restore a layout.
      Filters and calculated measures serialize as their expression text or
      structured tree (a `PredicateFilter` closure cannot be saved). Done
      2026-09-14: `CubeJson` / `CubeConfig` / `JsonAdapter` in the engine;
      the example app does not use it yet (a "Save/Load layout" action
      would be the natural demo once the filter editor exists).
- [x] Calculated aggregates: percent of row/column/grand total, difference
      from a base value (layout-relative wrappers, see above) and
      expression-based measures / derived aggregates from the expression
      language section. Engine and UI done 2026-09-14: the aggregate
      picker offers cell formulas and calculated measures, the chips
      "Show values as".
- [x] More data sources: JSON (array of objects) and JSONL, the formats
      every competitor reads; `ListDataSource` covers programmatic data
      already. Done 2026-09-15 in the engine (`JsonDataSource`,
      `JsonlDataSource`, `JsonCubeExporter` for both directions; nested
      objects flattened to dotted columns, arrays as JSON text). A
      database/server-side (lazy) source is a bigger design question;
      decide whether it is in scope at all (the snapshot format covers the
      "server does the import" case).
- [x] Charts: decide and document. The commercial pivots and om_data_grid
      pair the table with charts; tessera probably stays a table and
      leaves charts to the app (a `CubeLayout` → chart series helper would
      be the cheap middle ground). Decided 2026-09-15: tessera stays a
      table; the engine's `ChartData` / `ScatterData` (`lib/src/chart/`)
      produce chart-ready series from a layout, from facts or from one
      cell's drill-down, and the app draws them (`docs/15-charts.md`).
      A demo with a chart package in the example app is still open.
- [x] Trust signals after publishing: a screenshot-led README, the user
      guide, a CHANGELOG discipline and an issue template; the popular
      grids win on track record for a while. Done 2026-09-15: the README
      opens with the screenshot, `docs/` is the guide, every commit adds
      its CHANGELOG bullet under `## Unreleased`, bug / feature templates
      in `.github/ISSUE_TEMPLATE/`, and CI on every push.
