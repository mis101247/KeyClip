#!/usr/bin/env bash
set -euo pipefail

README="${README:-README.md}"
START="<!-- screenshots:start -->"
END="<!-- screenshots:end -->"
BLOCK="$(mktemp)"
OUTPUT="$(mktemp)"

cat > "${BLOCK}" <<'MARKDOWN'
<!-- screenshots:start -->
<p>
  <img src="docs/assets/screenshots/popover.png" alt="KeyClip clipboard popover" width="620">
</p>
<p>
  <img src="docs/assets/screenshots/settings-general.png" alt="KeyClip general settings" width="620">
</p>
<p>
  <img src="docs/assets/screenshots/settings-exclusions.png" alt="KeyClip exclusion settings" width="620">
</p>
<p>
  <img src="docs/assets/screenshots/settings-statistics.png" alt="KeyClip statistics settings" width="620">
</p>
<!-- screenshots:end -->
MARKDOWN

awk -v start="${START}" -v end="${END}" -v block_file="${BLOCK}" '
  $0 == start {
    while ((getline line < block_file) > 0) print line
    in_block = 1
    next
  }
  $0 == end {
    in_block = 0
    next
  }
  !in_block { print }
' "${README}" > "${OUTPUT}"

if ! grep -q "${START}" "${README}"; then
  {
    sed '1,/^$/p' "${README}"
    cat "${BLOCK}"
    sed '1,/^$/d' "${README}"
  } > "${OUTPUT}"
fi

mv "${OUTPUT}" "${README}"
rm -f "${BLOCK}"
echo "Updated ${README} screenshot block"
