#!/usr/bin/env bash
set -euo pipefail

SPARKLE_GENERATE_KEYS="${SPARKLE_GENERATE_KEYS:-}"

if [[ -z "${SPARKLE_GENERATE_KEYS}" ]]; then
    SPARKLE_GENERATE_KEYS="$(find .build -path '*/generate_keys' -type f -perm -111 | head -n 1 || true)"
fi

if [[ -z "${SPARKLE_GENERATE_KEYS}" || ! -x "${SPARKLE_GENERATE_KEYS}" ]]; then
    echo "Sparkle generate_keys tool not found. Run swift package resolve first." >&2
    exit 1
fi

"${SPARKLE_GENERATE_KEYS}"
