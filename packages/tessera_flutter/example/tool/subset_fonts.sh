#!/bin/sh
# Subsets Noto Sans for the PDF export: Latin, Latin-1, Latin Extended-A/B
# (Hungarian ő/ű live in Extended-A), general punctuation (… – — quotes),
# currency symbols and a few letterlike symbols. Needs fonttools
# (`pyftsubset`). Source: the full fonts from the system or a download.
#
#   tool/subset_fonts.sh [source directory]   (default /usr/share/fonts/noto)
set -e
src=${1:-/usr/share/fonts/noto}
dst=$(dirname "$0")/../assets/fonts
for face in Regular Bold; do
  pyftsubset "$src/NotoSans-$face.ttf" \
    --unicodes="U+0000-024F,U+02C6-02DC,U+2000-206F,U+20A0-20CF,U+2100-214F,U+2190-2199,U+2212" \
    --layout-features='*' --no-hinting --desubroutinize \
    --output-file="$dst/NotoSans-$face.ttf"
  ls -l "$dst/NotoSans-$face.ttf"
done
