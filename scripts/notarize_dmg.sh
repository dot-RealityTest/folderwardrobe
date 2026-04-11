#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_DISPLAY_NAME="folderwardrobe"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/${APP_DISPLAY_NAME}.app"
DMG_PATH="$DIST_DIR/${APP_DISPLAY_NAME}.dmg"

APPLE_ID="${APPLE_ID:-}"
APPLE_TEAM_ID="${APPLE_TEAM_ID:-}"
APPLE_APP_PASSWORD="${APPLE_APP_PASSWORD:-${APPLE_PASSWORD:-}}"
SIGN_IDENTITY="${SIGN_IDENTITY:-}"

if [[ -z "$APPLE_ID" || -z "$APPLE_TEAM_ID" || -z "$APPLE_APP_PASSWORD" ]]; then
  echo "Missing Apple notarization credentials."
  echo "Set APPLE_ID, APPLE_TEAM_ID, and APPLE_APP_PASSWORD (or APPLE_PASSWORD)."
  exit 1
fi

if [[ -z "$SIGN_IDENTITY" ]]; then
  SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -n 1)"
fi
if [[ -z "$SIGN_IDENTITY" ]]; then
  echo "No Developer ID Application signing identity found in keychain."
  exit 1
fi

echo "Using signing identity: $SIGN_IDENTITY"

SIGN_IDENTITY="$SIGN_IDENTITY" ./scripts/package_dmg.sh

codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
codesign --verify --strict --verbose=2 "$DMG_PATH"

SUBMIT_JSON="$(mktemp)"
xcrun notarytool submit "$DMG_PATH" \
  --apple-id "$APPLE_ID" \
  --team-id "$APPLE_TEAM_ID" \
  --password "$APPLE_APP_PASSWORD" \
  --wait \
  --output-format json > "$SUBMIT_JSON"

STATUS="$(plutil -extract status raw -o - "$SUBMIT_JSON" 2>/dev/null || true)"
SUBMISSION_ID="$(plutil -extract id raw -o - "$SUBMIT_JSON" 2>/dev/null || true)"

echo "Notary submission ID: ${SUBMISSION_ID:-unknown}"
echo "Notary status: ${STATUS:-unknown}"

if [[ "$STATUS" != "Accepted" ]]; then
  echo "Notarization failed. Fetch log with:"
  echo "xcrun notarytool log ${SUBMISSION_ID:-<id>} --apple-id <APPLE_ID> --team-id <TEAM_ID> --password <APP_PASSWORD>"
  cat "$SUBMIT_JSON"
  rm -f "$SUBMIT_JSON"
  exit 1
fi

xcrun stapler staple "$APP_BUNDLE"
xcrun stapler staple "$DMG_PATH"

spctl -a -vvv --type exec "$APP_BUNDLE" || true
spctl -a -vvv --type open "$DMG_PATH" || true

rm -f "$SUBMIT_JSON"

echo "Notarized and stapled app: $APP_BUNDLE"
echo "Notarized and stapled dmg: $DMG_PATH"
