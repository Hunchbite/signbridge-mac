#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
command -v xcodegen >/dev/null || { echo "brew install xcodegen"; exit 1; }
xcodegen generate
xcodebuild -scheme SignBridge -configuration Debug -derivedDataPath build CODE_SIGN_IDENTITY="-" build
open build/Build/Products/Debug/SignBridge.app
echo "SignBridge is in the menu bar (signature glyph)."
