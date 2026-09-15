---
name: Bug report
about: Something behaves differently from what the documentation says
labels: bug
---

**Package and version**
`tessera` / `tessera_flutter` / `tessera_xlsx` / `tessera_ods` / `tessera_html` / `tessera_svg` / `tessera_pdf`, version x.y.z
(`dart pub deps | grep tessera`)

**Environment**
Output of `flutter --version` (or `dart --version`), and the platform
(Linux / macOS / Windows / Android / iOS / web).

**What happened**
A clear description, with the error text and stack trace if there is one.

**What you expected**

**How to reproduce**
The smallest thing that shows it — ideally a `CubeSpec` plus a few rows of
data (`ListDataSource` or a small CSV), or a failing test. For import
problems, a snippet of the file and the schema (`inferSchema` output or
your `ColumnSpec`s).
