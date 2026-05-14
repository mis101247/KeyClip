#!/usr/bin/env bash
set -euo pipefail

APP_NAME="KeyClip"
BUNDLE_ID="com.keyo.KeyClip"
VERSION="${VERSION:-1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
UPDATE_FEED_URL="${UPDATE_FEED_URL:-}"
SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-}"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"
APP_BUNDLE="./${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
FRAMEWORKS_DIR="${CONTENTS_DIR}/Frameworks"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
INFO_PLIST="${CONTENTS_DIR}/Info.plist"
ICON_PATH="${RESOURCES_DIR}/AppIcon.icns"
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
SPARKLE_FRAMEWORK_PATH="$(find .build -path '*/Sparkle.framework' -type d | head -n 1)"
RESOURCE_BUNDLE_PATH="$(find "${BUILD_DIR}" -maxdepth 1 -name "${APP_NAME}_${APP_NAME}.bundle" -type d | head -n 1)"

if [[ ! -x "${EXECUTABLE_PATH}" ]]; then
    echo "Built executable not found at ${EXECUTABLE_PATH}" >&2
    exit 1
fi

if [[ ! -d "${SPARKLE_FRAMEWORK_PATH}" ]]; then
    echo "Sparkle.framework not found under .build" >&2
    exit 1
fi

rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}" "${FRAMEWORKS_DIR}" "${RESOURCES_DIR}"

cp "${EXECUTABLE_PATH}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"
if ! otool -l "${MACOS_DIR}/${APP_NAME}" | grep -q '@executable_path/../Frameworks'; then
    install_name_tool -add_rpath "@executable_path/../Frameworks" "${MACOS_DIR}/${APP_NAME}"
fi
cp -R "${SPARKLE_FRAMEWORK_PATH}" "${FRAMEWORKS_DIR}/Sparkle.framework"

if [[ -n "${RESOURCE_BUNDLE_PATH}" ]]; then
    cp -R "${RESOURCE_BUNDLE_PATH}" "${RESOURCES_DIR}/"
fi

swift scripts/generate_icon.swift "${ICON_PATH}"

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
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

if [[ -n "${UPDATE_FEED_URL}" ]]; then
    /usr/libexec/PlistBuddy -c "Add :SUFeedURL string ${UPDATE_FEED_URL}" "${INFO_PLIST}"
fi

if [[ -n "${SPARKLE_PUBLIC_ED_KEY}" ]]; then
    /usr/libexec/PlistBuddy -c "Add :SUPublicEDKey string ${SPARKLE_PUBLIC_ED_KEY}" "${INFO_PLIST}"
fi

plutil -lint "${INFO_PLIST}" >/dev/null

if [[ -n "${CODESIGN_IDENTITY}" ]]; then
    CODESIGN_ARGS=(--force --deep --sign "${CODESIGN_IDENTITY}")
    if [[ "${CODESIGN_IDENTITY}" != "-" ]]; then
        CODESIGN_ARGS+=(--options runtime --timestamp)
    fi
    codesign "${CODESIGN_ARGS[@]}" "${APP_BUNDLE}"
fi

echo "Built ${APP_NAME}.app — run with: open ${APP_NAME}.app"
