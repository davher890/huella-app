#!/usr/bin/env bash
# Builds the Flutter web app and copies the output (build/web/) into the
# the-horse-tracker-api repo's public/app/, replacing what's there.
# Assumes both repos are checked out as sibling directories (../the-horse-tracker-api).
#
# This only builds and moves files — it doesn't commit/push. Do that from
# the API repo afterwards (see that repo's README).

set -euo pipefail

cd "$(dirname "$0")/.."

SRC="build/web"
API_REPO="../the-horse-tracker-api"
DEST="$API_REPO/public/app"

if [ ! -d "$API_REPO" ]; then
  echo "error: $API_REPO not found (expected as a sibling directory)." >&2
  exit 1
fi

# --base-href /app/ is required: without it, the generated index.html
# requests its assets from /, which 404s once served from a subpath.
flutter build web --base-href /app/

rm -rf "$DEST"
mkdir -p "$DEST"
cp -r "$SRC"/* "$DEST"/

echo "Copied $SRC -> $DEST"
echo "Next: cd $API_REPO && git add public/app && git commit && git push"
