#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Remuxer"
CONFIGURATION="${CONFIGURATION:-Release}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_DIR="$ROOT_DIR/.derivedData/dist"
DIST_DIR="$ROOT_DIR/dist"
BUILT_APP="$DERIVED_DATA_DIR/Build/Products/$CONFIGURATION/$APP_NAME.app"
DIST_APP="$DIST_DIR/$APP_NAME.app"

usage() {
  cat <<EOF
Build a local Remuxer.app bundle into dist/.

Usage:
  scripts/dist.sh [--debug] [--open]

Options:
  --debug   Build Debug instead of Release.
  --open    Reveal the built app in Finder when done.
  --help    Show this help.

Output:
  dist/Remuxer.app
EOF
}

SHOULD_REVEAL=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --debug|debug)
      CONFIGURATION="Debug"
      BUILT_APP="$DERIVED_DATA_DIR/Build/Products/$CONFIGURATION/$APP_NAME.app"
      ;;
    --open|open)
      SHOULD_REVEAL=true
      ;;
    --help|-h|help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac

  shift
done

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

mkdir -p "$DIST_DIR"

if [[ -e "$DIST_APP" ]]; then
  case "$DIST_APP" in
    "$DIST_DIR"/*.app)
      rm -rf "$DIST_APP"
      ;;
    *)
      echo "Refusing to remove unexpected path: $DIST_APP" >&2
      exit 1
      ;;
  esac
fi

echo "Building $APP_NAME ($CONFIGURATION)..."
xcodebuild \
  -project "$ROOT_DIR/Remuxer.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration "$CONFIGURATION" \
  -destination "platform=macOS" \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  CODE_SIGNING_ALLOWED=NO \
  build

ditto "$BUILT_APP" "$DIST_APP"

for tool in ffmpeg ffprobe; do
  if [[ ! -x "$DIST_APP/Contents/Resources/FFmpeg/bin/$tool" ]]; then
    echo "Built app is missing bundled $tool." >&2
    exit 1
  fi
done

echo
echo "Built: $DIST_APP"
echo "You can drag dist/$APP_NAME.app into /Applications."

if [[ "$SHOULD_REVEAL" == true ]]; then
  /usr/bin/open -R "$DIST_APP"
fi
