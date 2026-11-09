#!/usr/bin/env sh
# Stage a clean `packages/preview/<name>/<version>/` directory matching
# https://github.com/typst/packages/blob/main/docs/tips.md
set -eu

ALLOW_VENDORED=0
OUT_ROOT="dist/universe"

for arg in "$@"; do
  case "$arg" in
    --allow-vendored) ALLOW_VENDORED=1 ;;
    *) OUT_ROOT="$arg" ;;
  esac
done

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$REPO_ROOT"

# `manifest.py` validates typst.toml and exits non-zero on a missing field.
PKG_NAME="$(python3 scripts/manifest.py get name)"
PKG_VER="$(python3 scripts/manifest.py get version)"

# Guard against staging for Typst Universe while unpublished dependencies remain in vendor/
if [ "$ALLOW_VENDORED" -eq 0 ] && [ -d vendor ] && [ -n "$(find vendor -mindepth 1 -maxdepth 2 -name typst.toml 2>/dev/null)" ]; then
  echo "stage-universe: vendor/ still contains unpublished dependencies:" >&2
  find vendor -mindepth 1 -maxdepth 2 -name typst.toml >&2
  echo "Wait for upstream release on Typst Universe, remove vendor/, and re-run (or pass --allow-vendored for a local dry run)." >&2
  exit 1
fi

# Verify @preview/<name>:<version> imports match typst.toml across template, examples, tests, docs, and README
EXPECTED_IMPORT="@preview/${PKG_NAME}:${PKG_VER}"
STALE_IMPORTS="$(grep -rn "@preview/${PKG_NAME}:" template examples tests/unit.typ docs/manual.typ README.md | grep -v "${EXPECTED_IMPORT}" || true)"
if [ -n "$STALE_IMPORTS" ]; then
  echo "stage-universe: version mismatch (expected ${EXPECTED_IMPORT}):" >&2
  echo "$STALE_IMPORTS" >&2
  exit 1
fi

DEST="${OUT_ROOT}/packages/preview/${PKG_NAME}/${PKG_VER}"
rm -rf "$DEST"
mkdir -p "$DEST/docs" "$DEST/assets"

# Group 1: Required package & template files (included in compiler archive)
cp typst.toml LICENSE README.md "$DEST/"
cp -R src template "$DEST/"

# Template thumbnail (automatically excluded from compiler archive by Typst)
cp thumbnail.png "$DEST/"

# Group 2: Documentation & showcase files linked from README.md (excluded via typst.toml `exclude`)
cp docs/manual.pdf "$DEST/docs/manual.pdf"
cp assets/preview-light.png assets/preview-dark.png "$DEST/assets/"
cp -R examples "$DEST/"

# Strip any stray OS metadata files
find "$DEST" -name '.DS_Store' -delete

echo "staged ${PKG_NAME}:${PKG_VER} -> ${DEST}"
