# tessera — project notes for Claude

Flutter library (pub.dev package, not yet published) for analyzing, grouping
and aggregating tabular data: a pivot-table engine plus a widget. Owner:
László Zsolt Nagy (nagylzs@gmail.com). MIT.

## Commands

```bash
flutter analyze                      # must be clean (flutter_lints)
flutter test                         # unit tests in test/
dart format lib test example/lib     # run before committing
flutter pub publish --dry-run        # pub.dev validation; keep at 0 warnings
cd example && dart run tool/gen_sales_csv.dart   # regenerate assets/sales.csv (seeded)
```

## Status

- API skeleton written with doc comments in `lib/src/`; value types are
  implemented, behaviour throws `UnimplementedError` (CSV parsing,
  `inferSchema`, `FactTableImporter.import`, all `Accumulator`s,
  `Cube._computeLayout`, `expand*ToDepth`, `CubeView.build`, ISO week).
- `example/` is the untouched `flutter create` app plus `assets/sales.csv`.
- README describes the target API. `pubspec.yaml` `description` is set;
  `CHANGELOG.md` is the template.

## Architecture (see `lib/tessera.dart` doc for the long version)

Four layers, one directory each under `lib/src/`:

1. `schema/` + `source/` — `DataSource` (column names + re-openable
   `Stream<SourceRow>`), `inferSchema` samples a prefix of rows,
   `ColumnSpec` carries user overrides (type, include, format, parser).
2. `facts/` — `FactTableImporter` → immutable `FactTable` (columnar,
   dictionary-encoded, typed lists so it can move to an isolate).
   `Dimension` (sealed: `ColumnDimension`, `DatePartDimension`,
   `MappedDimension`) and `Measure` are *views on columns*, not column
   properties — any column can be grouped by, numeric ones aggregated.
3. `cube/` — `CubeSpec` (row/column `CubeAxis`, `aggregates`, `filter`) +
   one `ExpansionState` per axis → `Cube` (immutable, `late final layout`)
   → `CubeLayout` / `AxisLayout` / `HeaderEntry` / `CubeCell`.
4. `widgets/` — `CubeController extends ChangeNotifier` holds the cube;
   `CubeView` renders one aggregate per cell.

Layers 1–3 must not import Flutter.

## Key design decisions (agreed with the owner)

- **Summary = root path.** `DimensionPath.root` (empty) is the summary
  row/column. `ExpansionState.initial()` has only the root expanded, which
  makes the first level visible. Expanded parent rows double as subtotals
  (outline/tree-grid model, no separate subtotal rows).
- **Nesting order is the hierarchy.** `[region, country]` groups by region
  then country; no hierarchy declarations. A dimension may appear on at most
  one axis; different derived dimensions of the same column (`date.year`,
  `date.month`) may be on different axes.
- **Empty values are groups, not dropped.** `null` dimension value = the
  "(empty)" group, distinct from the summary. Measures: `sum` ignores nulls,
  `avg` divides by non-null count, `count` ≠ `countNonNull`. A cell with
  `factCount == 0` renders blank.
- **Cells never store row lists.** Aggregation is a single pass over facts
  updating accumulators for every visible (row-prefix, col-prefix) pair;
  `CubeCell.factRows` is a lazy filter. `Accumulator` is
  `add / merge / result` so parents merge from children (avg carries
  sum+count).
- **Type inference is a proposal.** `inferSchema` reads `sampleRows`;
  `TypeMismatchPolicy` (`widen` default / `nullify` / `fail`) resolves
  contradictions during import. Widening order in `ColumnType.canWidenTo`.
- **Filter is separate from axes** (pivot "filter area"), sorting lives on
  `AxisDimension.sort` (by value or by aggregate, null position).
- **Immutable values everywhere**; `CubeController` is the only mutable
  object. `copyWith` for derived versions; equality by value (`Dimension`
  and `Aggregate` by `id`).
- **Naming avoids Flutter clashes**: never `Row`, `Column`, `Axis`, `Table`,
  `Cell` — use `CubeAxis`, `HeaderEntry`, `CubeCell`, etc.
- Web support matters: no `dart:io` in the library; sources are byte/stream
  based.
- Import and aggregation are expected to run in an isolate for large data.

## Test data

`example/assets/sales.csv` — 1000 rows, columns `id,date,region,country,
category,product,salesperson,quantity,unit_price,discount,total`.
Deliberate edge cases (probabilities in `example/tool/gen_sales_csv.dart`):
rows with region but no country/category/product; category without product;
missing quantity or unit_price (then total is empty too); countries with no
region (Iceland, Singapore); products with no category (Gift Card, Extended
Warranty, Shipping); some empty discounts and salespeople. Hierarchies are
consistent otherwise.

## Conventions

- `pubspec.yaml` has no `author` field on purpose (deprecated, pub warns);
  author lives in README and LICENSE.
- Example app org id: `eu.nagylzs` (`eu.nagylzs.tessera_example`).
- Doc comments on every public type; keep the library-level doc in
  `lib/tessera.dart` in sync with the layer list above.
- Test the pure-Dart layers directly; widget tests only for `widgets/`.
