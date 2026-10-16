#!/usr/bin/env bash
set -euo pipefail

: "${API_BASE_URL:?Set API_BASE_URL to the public HTTPS SDS-DB API URL}"
: "${GOOGLE_WEB_CLIENT_ID:?Set GOOGLE_WEB_CLIENT_ID to the Google web OAuth client ID}"

case "$API_BASE_URL" in
  https://*) ;;
  *) echo "API_BASE_URL must use HTTPS." >&2; exit 1 ;;
esac
case "$API_BASE_URL" in
  *localhost*|*127.0.0.1*|*10.0.2.2*)
    echo "API_BASE_URL must point to a publicly reachable server." >&2
    exit 1
    ;;
esac
API_BASE_URL="${API_BASE_URL%/}"

cd "$(dirname "$0")/../app"
../scripts/check-release-config.mjs 2>/dev/null || node ../scripts/check-release-config.mjs
mkdir -p ../artifacts/symbols
flutter clean
flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter build appbundle --release \
  --dart-define=API_BASE_URL="$API_BASE_URL" \
  --dart-define=GOOGLE_WEB_CLIENT_ID="$GOOGLE_WEB_CLIENT_ID" \
  --obfuscate \
  --split-debug-info=../artifacts/symbols
