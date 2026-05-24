#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

if [[ "${1:-}" == "--fix" ]]; then
  swiftlint --fix --no-cache --config "$ROOT_DIR/.swiftlint.yml"
fi

swift format lint \
  --configuration "$ROOT_DIR/.swift-format" \
  --recursive \
  --strict \
  "$ROOT_DIR/Remuxer" \
  "$ROOT_DIR/RemuxerTests"

swiftlint lint --strict --no-cache --config "$ROOT_DIR/.swiftlint.yml"

