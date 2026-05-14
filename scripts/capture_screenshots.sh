#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${OUT_DIR:-docs/assets/screenshots}"
APP_NAME="KeyClip"
APP_EXEC="./${APP_NAME}.app/Contents/MacOS/${APP_NAME}"

targets=(
  "popover:popover.png"
  "settingsGeneral:settings-general.png"
  "settingsExclusions:settings-exclusions.png"
  "settingsStatistics:settings-statistics.png"
)

mkdir -p "${OUT_DIR}"
./build.sh >/dev/null

capture_target() {
  local target="$1"
  local filename="$2"
  local output="${OUT_DIR}/${filename}"

  KEYCLIP_DEMO=1 \
    KEYCLIP_DEMO_TARGET="${target}" \
    KEYCLIP_DEMO_CAPTURE_DIR="${OUT_DIR}" \
    "${APP_EXEC}" >/tmp/keyclip-demo-${target}.log 2>&1
  sips --resampleWidth 1240 "${output}" >/dev/null
  swift scripts/flatten_png.swift "${output}"
  echo "Captured ${output}"
}

for entry in "${targets[@]}"; do
  IFS=":" read -r target filename <<< "${entry}"
  capture_target "${target}" "${filename}"
done
