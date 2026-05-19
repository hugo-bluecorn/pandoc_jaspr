#!/usr/bin/env bash
# Verify the spike's rendered article HTML matches the committed golden.
#
# Runs `jaspr build` in spike/example_app/ and diffs the result against
# spike/golden/article.html. Exits 0 on match, 1 on diff (and prints the
# diff). Use spike/golden/regenerate.sh to accept an intentional change.
set -euo pipefail

GOLDEN_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$GOLDEN_DIR/../example_app"
ROUTE_HTML="$APP_DIR/build/jaspr/article.pandoc"
GOLDEN_HTML="$GOLDEN_DIR/article.html"

export PATH="$PATH:$HOME/.pub-cache/bin"

(cd "$APP_DIR" && rm -rf build/jaspr && jaspr build)

if [[ ! -f "$ROUTE_HTML" ]]; then
  echo "ERROR: jaspr build did not produce $ROUTE_HTML" >&2
  exit 1
fi

if diff -u "$GOLDEN_HTML" "$ROUTE_HTML"; then
  echo "OK: rendered HTML matches golden ($(wc -c < "$GOLDEN_HTML") bytes)"
else
  echo
  echo "MISMATCH: rendered HTML differs from $GOLDEN_HTML" >&2
  echo "If the change is intentional, run spike/golden/regenerate.sh and commit." >&2
  exit 1
fi
