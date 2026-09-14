# Tessera user guide

Tessera turns a flat table of facts — a CSV file, a spreadsheet, rows
from your own code — into an interactive pivot table: group by any
columns on two axes, expand and collapse groups, sort, filter, aggregate,
show the result in a Flutter grid or write it to a file. This guide walks
through the pieces in the order you meet them. The package READMEs are
the short version; this is the long one.

![The Simple pivot example: regions and countries against years and quarters, Europe and 2024 expanded, Germany × Q2 selected](images/cube_view.png)

| Chapter | What it covers |
|---|---|
| [1. Getting started](01-getting-started.md) | Install the packages, load a CSV, build a cube, show it. The example app. |
| [2. Data sources](02-data-sources.md) | CSV, lists, Excel and OpenDocument sheets, HTTP, your own `DataSource`, snapshots. |
| [3. Schema and import](03-schema.md) | Type inference, `ColumnSpec` overrides, parsing rules, the import report, what happens to values that do not fit. |
| [4. Facts, dimensions and measures](04-facts-dimensions-measures.md) | The fact table, and the two kinds of views on it that a cube is built from. |
| [5. The cube](05-cube.md) | `CubeSpec`, axes, expansion, sorting, summaries and subtotals, reading the layout. |
| [6. Aggregates](06-aggregates.md) | Sum to variance, calculated measures, cell formulas, "show values as", your own. |
| [7. Filters](07-filters.md) | Structured filters, expression filters, the filter editor. |
| [8. The expression language](08-expressions.md) | Grammar, types, empty values, built-in functions, application functions. |
| [9. The widgets](09-widgets.md) | `CubeController`, `CubeView`, the editors and pickers, keyboard navigation. |
| [10. Theming](10-theming.md) | `CubeTheme`, level colours, hue levels, the presets. |
| [11. Export](11-export.md) | CSV, XLSX, ODS, HTML, SVG, PDF and the shared `CubeExportTheme`. |
| [12. Localization](12-localization.md) | Fourteen built-in languages, `TesseraLocalizations`, adding your own. |
| [13. Saving and restoring](13-saving.md) | JSON for the pivot configuration; binary snapshots of the data. |
| [14. Large data](14-large-data.md) | Isolates, progress, cancellation, what to expect from millions of rows. |
| [Snapshot format](snapshot.md) | The byte layout of `.tsnp` files, for writers in other languages. |

Every example in the guide uses `sales.csv`, the 1000-row file that ships
with the packages (`packages/tessera/example/sales.csv`, also the demo
app's asset): orders with a date, region, country, category, product,
salesperson, quantity, unit price, discount and total, with some values
deliberately missing so the "(empty)" groups have something to show.

The screenshots come from the demo app in `packages/tessera_flutter/example`,
which you can run on any desktop with `flutter run`.
