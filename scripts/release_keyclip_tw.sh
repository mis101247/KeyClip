#!/usr/bin/env bash
set -euo pipefail

export SITE_BASE_URL="${SITE_BASE_URL:-https://keyclip.keyo.tw}"
export UPDATE_FEED_URL="${UPDATE_FEED_URL:-${SITE_BASE_URL%/}/appcast.xml}"
export SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-mYtNaSDQ4MvZWsFkLf+HS8PX7BFCYwFQ35S4wcJQPyg=}"

./release_dmg.sh
