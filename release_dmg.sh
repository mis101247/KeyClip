#!/usr/bin/env bash
set -euo pipefail

APP_NAME="KeyClip"
VERSION="${VERSION:-1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
APP_BUNDLE="./${APP_NAME}.app"
DIST_DIR="./dist"
DMG_ROOT="${DIST_DIR}/dmg-root"
DMG_PATH="${DIST_DIR}/${APP_NAME}-${VERSION}.dmg"
APPCAST_DIR="${APPCAST_DIR:-${DIST_DIR}/appcast}"
SITE_DIR="${SITE_DIR:-${DIST_DIR}/site}"
SITE_BASE_URL="${SITE_BASE_URL:-https://keyclip.keyo.tw}"
VERCEL_ORG_ID="${VERCEL_ORG_ID:-team_TSWYZBy6KbP6clqIAxwvW3jy}"
VERCEL_PROJECT_ID="${VERCEL_PROJECT_ID:-prj_ZEIx3FWbtKQNcELQ4E7PSAdO75dQ}"
SPARKLE_GENERATE_APPCAST="${SPARKLE_GENERATE_APPCAST:-}"
SPARKLE_PRIVATE_ED_KEY="${SPARKLE_PRIVATE_ED_KEY:-}"
SPARKLE_PRIVATE_ED_KEY_FILE="${SPARKLE_PRIVATE_ED_KEY_FILE:-}"
APPCAST_DOWNLOAD_URL_PREFIX="${APPCAST_DOWNLOAD_URL_PREFIX:-}"
APPCAST_LINK_URL="${APPCAST_LINK_URL:-}"
NOTARIZE="${NOTARIZE:-0}"

SITE_BASE_URL="${SITE_BASE_URL%/}"
if [[ -z "${APPCAST_DOWNLOAD_URL_PREFIX}" && -n "${SITE_BASE_URL}" ]]; then
    APPCAST_DOWNLOAD_URL_PREFIX="${SITE_BASE_URL}/download/"
fi
if [[ -z "${APPCAST_LINK_URL}" && -n "${SITE_BASE_URL}" ]]; then
    APPCAST_LINK_URL="${SITE_BASE_URL}/"
fi

VERSION="${VERSION}" BUILD_NUMBER="${BUILD_NUMBER}" ./build.sh

rm -rf "${DMG_ROOT}"
mkdir -p "${DMG_ROOT}" "${DIST_DIR}" "${APPCAST_DIR}"

cp -R "${APP_BUNDLE}" "${DMG_ROOT}/${APP_NAME}.app"
ln -s /Applications "${DMG_ROOT}/Applications"

rm -f "${DMG_PATH}"
hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${DMG_ROOT}" \
    -ov \
    -format UDZO \
    "${DMG_PATH}"

rm -rf "${DMG_ROOT}"

echo "Built ${DMG_PATH}"
echo "Users can open the DMG and drag ${APP_NAME}.app to Applications."

if [[ "${NOTARIZE}" == "1" ]]; then
    VERSION="${VERSION}" ./scripts/notarize_dmg.sh "${DMG_PATH}"
fi

cp "${DMG_PATH}" "${APPCAST_DIR}/"

if [[ -z "${SPARKLE_GENERATE_APPCAST}" ]]; then
    SPARKLE_GENERATE_APPCAST="$(find .build -path '*/generate_appcast' -type f -perm -111 | head -n 1 || true)"
fi

if [[ -n "${SPARKLE_GENERATE_APPCAST}" && -x "${SPARKLE_GENERATE_APPCAST}" ]]; then
    APPCAST_ARGS=()
    if [[ -n "${SPARKLE_PRIVATE_ED_KEY_FILE}" ]]; then
        APPCAST_ARGS+=(--ed-key-file "${SPARKLE_PRIVATE_ED_KEY_FILE}")
    elif [[ -n "${SPARKLE_PRIVATE_ED_KEY}" ]]; then
        APPCAST_ARGS+=(--ed-key-file -)
    fi
    if [[ -n "${APPCAST_DOWNLOAD_URL_PREFIX}" ]]; then
        APPCAST_ARGS+=(--download-url-prefix "${APPCAST_DOWNLOAD_URL_PREFIX}")
    fi
    if [[ -n "${APPCAST_LINK_URL}" ]]; then
        APPCAST_ARGS+=(--link "${APPCAST_LINK_URL}")
    fi

    if [[ -n "${SPARKLE_PRIVATE_ED_KEY}" && -z "${SPARKLE_PRIVATE_ED_KEY_FILE}" ]]; then
        printf '%s' "${SPARKLE_PRIVATE_ED_KEY}" | "${SPARKLE_GENERATE_APPCAST}" "${APPCAST_ARGS[@]}" "${APPCAST_DIR}"
    else
        "${SPARKLE_GENERATE_APPCAST}" "${APPCAST_ARGS[@]}" "${APPCAST_DIR}"
    fi
    echo "Built Sparkle appcast in ${APPCAST_DIR}"
else
    echo "Sparkle generate_appcast tool not found. Set SPARKLE_GENERATE_APPCAST=/path/to/generate_appcast to generate appcast.xml." >&2
fi

rm -rf "${SITE_DIR}"
mkdir -p "${SITE_DIR}/download"
mkdir -p "${SITE_DIR}/.vercel"
cp "${DMG_PATH}" "${SITE_DIR}/download/"
if [[ -f "${APPCAST_DIR}/appcast.xml" ]]; then
    cp "${APPCAST_DIR}/appcast.xml" "${SITE_DIR}/appcast.xml"
fi

cat > "${SITE_DIR}/index.html" <<HTML
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>KeyClip</title>
  <style>
    :root {
      color-scheme: light dark;
      font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "Segoe UI", sans-serif;
      background: Canvas;
      color: CanvasText;
    }
    body {
      margin: 0;
      min-height: 100vh;
      display: grid;
      place-items: center;
      padding: 40px 20px;
    }
    main {
      width: min(680px, 100%);
    }
    h1 {
      margin: 0 0 12px;
      font-size: clamp(42px, 8vw, 72px);
      letter-spacing: 0;
      line-height: 1;
    }
    p {
      margin: 0 0 24px;
      max-width: 560px;
      color: color-mix(in srgb, CanvasText 72%, Canvas);
      font-size: 18px;
      line-height: 1.5;
    }
    a.button {
      display: inline-flex;
      align-items: center;
      min-height: 44px;
      padding: 0 18px;
      border-radius: 8px;
      background: #0b6b8f;
      color: white;
      font-weight: 650;
      text-decoration: none;
    }
    small {
      display: block;
      margin-top: 16px;
      color: color-mix(in srgb, CanvasText 56%, Canvas);
    }
  </style>
</head>
<body>
  <main>
    <h1>KeyClip</h1>
    <p>A fast clipboard manager for macOS that lives in your menu bar and keeps clipboard history local to your Mac.</p>
    <a class="button" href="download/${APP_NAME}-${VERSION}.dmg">Download for macOS</a>
    <small>Version ${VERSION} · macOS 13 or newer</small>
  </main>
</body>
</html>
HTML

cat > "${SITE_DIR}/.vercel/project.json" <<JSON
{"orgId":"${VERCEL_ORG_ID}","projectId":"${VERCEL_PROJECT_ID}"}
JSON

echo "Built static release site in ${SITE_DIR}"
