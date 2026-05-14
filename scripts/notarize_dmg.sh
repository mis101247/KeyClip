#!/usr/bin/env bash
set -euo pipefail

VERSION="${VERSION:-1.0}"
DMG_PATH="${1:-dist/KeyClip-${VERSION}.dmg}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
APPLE_ID="${APPLE_ID:-}"
APPLE_TEAM_ID="${APPLE_TEAM_ID:-}"
APP_SPECIFIC_PASSWORD="${APP_SPECIFIC_PASSWORD:-}"

if [[ ! -f "${DMG_PATH}" ]]; then
    echo "DMG not found: ${DMG_PATH}" >&2
    exit 1
fi

if [[ -n "${NOTARY_PROFILE}" ]]; then
    xcrun notarytool submit "${DMG_PATH}" \
        --keychain-profile "${NOTARY_PROFILE}" \
        --wait
elif [[ -n "${APPLE_ID}" && -n "${APPLE_TEAM_ID}" && -n "${APP_SPECIFIC_PASSWORD}" ]]; then
    xcrun notarytool submit "${DMG_PATH}" \
        --apple-id "${APPLE_ID}" \
        --team-id "${APPLE_TEAM_ID}" \
        --password "${APP_SPECIFIC_PASSWORD}" \
        --wait
else
    cat >&2 <<'MESSAGE'
Missing notarization credentials.

Use either:
  NOTARY_PROFILE=keyclip ./scripts/notarize_dmg.sh

or:
  APPLE_ID=you@example.com APPLE_TEAM_ID=TEAMID APP_SPECIFIC_PASSWORD=xxxx ./scripts/notarize_dmg.sh

Create a reusable keychain profile with:
  xcrun notarytool store-credentials keyclip --apple-id you@example.com --team-id TEAMID --password app-specific-password
MESSAGE
    exit 1
fi

xcrun stapler staple "${DMG_PATH}"
xcrun stapler validate "${DMG_PATH}"
spctl -a -vvv -t open --context context:primary-signature "${DMG_PATH}"

echo "Notarized and stapled ${DMG_PATH}"
