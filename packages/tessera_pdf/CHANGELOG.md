## Unreleased

* Fix: the page header and footer were drawn in the header cells' font
  colour, so a theme with light text on dark header fills (e.g.
  `CubeExportTheme.brand`) made the title, date and page numbers white on
  white paper. They now take the theme's cell font colour, or the new
  `PdfCubeExporter.pageTextColor`.

## 0.2.0

* Requires `tessera` 0.2.0; no changes of its own. Cubes with the new
  aggregates (statistical, cell formulas, "show values as") export like
  any other.

## 0.1.0

* Initial release: `PdfCubeExporter` writes a `CubeLayout` as a paginated
  PDF rendered from `CubeGrid` — merged group headers, one column per
  exported aggregate, fills and fonts from the engine's `CubeExportTheme`,
  localized labels and numbers, exact column widths from the embedded
  font's metrics, text ellipsized to its cell. `PageSetup` (A3/A4/A5/
  Letter/Legal or custom, orientation, margins in mm), fit to width with
  a `minScale` before tiling columns, header band and row header repeated
  on every page (`GridPagination`), a minimal page header and footer
  (`PdfPageText` with `{title}`, `{page}`, `{pages}`, `{date}`),
  `PdfFonts` for TrueType files (built-in Helvetica otherwise).
* `example/main.dart`: command-line export of `example/sales.csv`.
