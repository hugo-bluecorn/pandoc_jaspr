#!/usr/bin/env bash
# Regenerate the golden HTML for the spike article.
#
# Run this when an intentional change to the parser or layout has shifted
# the rendered HTML. Commit the resulting spike/golden/article.html
# diff in the same PR as the change that caused it.
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

cp "$ROUTE_HTML" "$GOLDEN_HTML"
echo "Regenerated $GOLDEN_HTML ($(wc -c < "$GOLDEN_HTML") bytes)"
