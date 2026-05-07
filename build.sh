#!/usr/bin/env bash
set -euo pipefail

APP_NAME="KeyClip"
BUNDLE_ID="com.keyo.KeyClip"
APP_BUNDLE="./${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
INFO_PLIST="${CONTENTS_DIR}/Info.plist"
SPM_CACHE_DIR=".build/spm-cache"
SPM_ARGS=(
    -c release
    --disable-sandbox
    --cache-path "${SPM_CACHE_DIR}"
    --manifest-cache local
)

export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-/tmp/${APP_NAME}-clang-module-cache}"

swift build "${SPM_ARGS[@]}"

BUILD_DIR="$(swift build "${SPM_ARGS[@]}" --show-bin-path)"
EXECUTABLE_PATH="${BUILD_DIR}/${APP_NAME}"

if [[ ! -x "${EXECUTABLE_PATH}" ]]; then
    echo "Built executable not found at ${EXECUTABLE_PATH}" >&2
    exit 1
fi

rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

cp "${EXECUTABLE_PATH}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

cat > "${INFO_PLIST}" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

plutil -lint "${INFO_PLIST}" >/dev/null

echo "Built ${APP_NAME}.app — run with: open ${APP_NAME}.app"
