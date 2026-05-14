#!/usr/bin/env bash
set -euo pipefail

npx vercel deploy dist/site --prod --yes --scope mis101247s-projects
