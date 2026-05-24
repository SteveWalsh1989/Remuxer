#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

xcodebuild \
  -project "$ROOT_DIR/Remuxer.xcodeproj" \
  -scheme Remuxer \
  -destination "platform=macOS" \
  -derivedDataPath "$ROOT_DIR/.derivedData" \
  build

