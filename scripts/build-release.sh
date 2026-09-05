#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../app"
../scripts/check-release-config.mjs 2>/dev/null || node ../scripts/check-release-config.mjs
mkdir -p ../artifacts/symbols
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build appbundle --release --obfuscate --split-debug-info=../artifacts/symbols
