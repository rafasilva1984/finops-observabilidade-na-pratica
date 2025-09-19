#!/usr/bin/env bash
# oneclick_import_v2.sh — robust import (path-safe) for Kibana Saved Objects
# Usage: bash scripts/oneclick_import_v2.sh [KIBANA_URL]
set -euo pipefail

KIBANA_URL="${1:-http://localhost:5601}"

# Resolve package path relative to this script's directory
# This makes it work no matter where you call it from.
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PKG_PATH="${SCRIPT_DIR%/}/../data/finops_oneclick_package.ndjson"

echo "[*] Using Kibana URL: $KIBANA_URL"
echo "[*] Looking for package at: $PKG_PATH"

if [[ ! -f "$PKG_PATH" ]]; then
  echo "[x] Package not found at: $PKG_PATH"
  echo "    Tip: ensure the file exists as data/finops_oneclick_package.ndjson"
  echo "    From repo root, try: ls -l data/finops_oneclick_package.ndjson"
  exit 2
fi

# Do the upload (overwrite=true so it's idempotent)
echo "[*] Importing package..."
curl -k -sS -X POST "$KIBANA_URL/api/saved_objects/_import?overwrite=true" \
  -H "kbn-xsrf: true" \
  --form "file=@${PKG_PATH}"

echo
echo "[*] Done. Open dashboard:"
echo "    $KIBANA_URL/app/dashboards#/view/dash-finops-oneclick-v1"
