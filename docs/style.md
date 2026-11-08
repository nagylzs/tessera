# Tessera style format (version 1)

A style says how every cell of a pivot table looks: its background, its
text colour and its font, by what the cell is and how deep it sits in the
row and column hierarchies, in a light and optionally a dark variant. One
style serves the screen (`CubeTheme.fromStyle` in `tessera_flutter`) and
every exported document (`CubeExportTheme.fromStyle`), so a spreadsheet,
a PDF or a web page looks like the grid it came from.

`JsonCubeStyle` reads this format; `CubeStyle` is the interface behind it,
for styles computed in code. Styles are written by hand, so reading is
strict: an unknown key, a wrong type or a malformed colour is an error that
names its place (`$.light.value.fill[1]: not a colour …`), never a silent
default.

## A whole style

```json
{
  "format": "tessera-style",
  "version": 1,
  "id": "teal",
  "name": {"en": "Teal", "hu": "Kékeszöld"},
  "metrics": {"rowHeight": 28, "headerRowHeight": 28, "padding": 6},
  "light": {
    "border": "#B2DFDB",
    "selection": "#E65100",
    "sortKey": "#40E65100",
    "icon": "#8A000000",
    "cell": {"fill": "#FFFFFF", "text": "#212121", "family": "sans", "size": 12},
    "header": {"fill": ["#80CBC4", "#B2DFDB"], "bold": [true, false]},
    "value": {"fill": ["#FFFFFF", "#F2F9F8", "#E0F2F1"]},
    "total": {"fill": "#B2DFDB", "bold": true},
    "title": {"italic": true}
  },
  "dark": {
    "border": "#00453E",
    "cell": {"fill": "#121212", "text": "#E0E0E0"},
    "header": {"fill": ["#00695C", "#004D40"]},
    "value": {"fill": ["#121212", "#16201F", "#1B2B29"]},
    "total": {"fill": "#004D40"}
  }
}
```

## Top level

| Key | | |
|---|---|---|
| `format` | required | `"tessera-style"` |
| `version` | required | `1`; a reader rejects versions it does not know |
| `id` | required | unique among the styles an app offers; what it stores as the user's choice |
| `name` | required | the name by language code (`en`, `hu`, `ja`, …); `en` is required and stands in for a missing language |
| `metrics` | optional | `rowHeight` (a row of values and row labels), `headerRowHeight` (a row of the column header band), `padding` (at each side of a cell's text), in logical pixels; 28, 28 and 6 by default |
| `light` | required | the light variant: what documents use, and the screen in light mode |
| `dark` | optional | the dark variant for the screen in dark mode; without it the style looks the same in dark mode, like paper |

## A variant

The colours around the cells, ARGB as below:

| Key | | |
|---|---|---|
| `border` | required in `light` | the grid lines |
| `selection` | optional | the current cell's outline; the app's primary colour by default |
| `sortKey` | optional | laid over the column whose values sort the rows; use a translucent colour |
| `icon` | optional | the headers' icons (expand, collapse, sort, the menu button); the header text's colour by default |

And a look for each role, plus two shared ones that others take from:

| Role | What | Takes what it does not set from |
|---|---|---|
| `cell` | — shared by all — | (nothing: it needs `fill` and `text`) |
| `header` | — shared by the headers — | `cell` |
| `value` | a value inside the table | `cell` |
| `total` | a value on the total row or column | `cell` |
| `rowLabel` | a row group's label | `header` |
| `columnLabel` | a column group's label | `header` |
| `title` | a dimension's name, on either axis | `header` |
| `corner` | the unused corner | `header` |
| `valueName` | a value's name under a column group | `columnLabel` |
| `totalLabel` | the total row's or column's label | `total` |

The `dark` variant looks along its own roles first, and takes from `light`
only what it sets nowhere along them. It must give `cell` a fill and a
text colour, so its colours are always its own and match each other; in
practice it sets colours only and leaves the fonts to `light`.

## A look

| Key | Value | |
|---|---|---|
| `fill` | colour, or a list by depth | the background |
| `text` | colour, or a list by depth | the text's colour |
| `family` | `"sans"`, `"serif"` or `"mono"` | the font; absent = what the surroundings use (the app's font on a screen, sans in a document) |
| `size` | number, or a list by depth | in logical pixels as on a screen; documents use five sixths of it in points, so 12 is 10 pt |
| `bold` | `true`/`false`, or a list by depth | |
| `italic` | `true`/`false`, or a list by depth | |

Colours are `"#RRGGBB"`, or `"#AARRGGBB"` with the alpha first, as Flutter
and Android write them (`"#40E65100"` is a quarter-opaque orange).

### Lists by depth

A list gives a value per depth from `0`, and its last entry serves every
deeper level: `"bold": [true, false]` makes the first level's labels bold
and none below. What the depth is depends on the property:

- **Colours** (`fill`, `text`) follow the depth the user's *depth
  coloring* picks — a choice of the app, not of the style
  (`DepthColoring`):
  - `both` (the default): a value takes its row depth plus its column
    depth; a header its depth on its own axis;
  - `rows`: a value takes its row's depth, so it matches its row label;
    column headers all take depth 0;
  - `columns`: the same by the column;
  - `off`: everything takes depth 0, one colour per role.
- **Fonts** (`size`, `bold`, `italic`) follow the cell's own depth,
  whatever the coloring: switching colours off does not change which
  labels are bold.

Totals, their labels and the corner are always at depth 0. A style that
wants depth to show should give `value` (and the headers) a list of fills,
with matching `text` colours where the fills get dark.

### Font families

A style names one of three kinds of font; each user of the style maps them
to fonts it has. Tessera Studio bundles Noto Sans, Noto Serif and Noto
Sans Mono and draws the screen and its PDFs with them. A document names
fonts its reader's machine is likely to have (`ExportFamilies`: Arial,
Times New Roman and Courier New by default).

## Comments

Keys starting with `_` are skipped wherever they are, for notes:
`"_why": "the reds of a ledger"`.
