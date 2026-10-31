#!/usr/bin/env bash
# Build the four CV PDF variants (EN/TR, with and without References).
#
# Usage: ./build-variants.sh [OUTPUT_DIR]
#   OUTPUT_DIR defaults to ~/Desktop/Alper-Sarper-CV-2026
#
# The sources are never modified: everything is compiled in a temporary copy.
# The no-references variants drop the standalone `\input{cv_xx/references.tex}`
# line together with the standalone `\newpage` line right before it.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${1:-$HOME/Desktop/Alper-Sarper-CV-2026}"
PREFIX="Alper-Sarper-CV-2026"
export PATH="/opt/homebrew/bin:/Library/TeX/texbin:$PATH"

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/cv-variants.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

mkdir -p "$OUT_DIR"
cp -R "$REPO_DIR/examples" "$WORK_DIR/examples"
# examples/awesome-cv.cls is a symlink to ../awesome-cv.cls
cp "$REPO_DIR/awesome-cv.cls" "$WORK_DIR/awesome-cv.cls"
# Drop stale build artefacts copied from the repo so latexmk always rebuilds.
find "$WORK_DIR/examples" -maxdepth 1 -type f \( -name "*.pdf" -o -name "*.xdv" -o -name "*.fdb_latexmk" -o -name "*.fls" -o -name "*.aux" -o -name "*.log" -o -name "*.out" -o -name "*.synctex.gz" \) -delete

build() { # <tex basename without .tex> <output pdf name>
  local name="$1" out="$2"
  (cd "$WORK_DIR/examples" && latexmk -xelatex -interaction=nonstopmode -halt-on-error -quiet "$name.tex" >/dev/null)
  cp "$WORK_DIR/examples/$name.pdf" "$OUT_DIR/$out"
  echo "built $OUT_DIR/$out"
}

for lang in en tr; do
  LANG_UP="$(echo "$lang" | tr '[:lower:]' '[:upper:]')"
  src="$WORK_DIR/examples/cv.$lang.tex"

  build "cv.$lang" "$PREFIX-$LANG_UP.pdf"

  # No-references variant: remove the `\newpage` + `\input{cv_xx/references.tex}` pair.
  noref="$WORK_DIR/examples/cv.$lang.noref.tex"
  awk -v ref="\\\\input{cv_${lang}/references.tex}" '
    $0 == "\\newpage" { held = $0; next }
    held != "" { if ($0 == ref) { held = ""; next } print held; held = "" }
    $0 == ref { next }
    { print }
    END { if (held != "") print held }
  ' "$src" > "$noref"
  if grep -q "references.tex" "$noref" && grep -qE '^\\input\{cv_'"$lang"'/references\.tex\}$' "$noref"; then
    echo "error: references input still present in $noref" >&2; exit 1
  fi
  build "cv.$lang.noref" "$PREFIX-$LANG_UP-no-references.pdf"
done
