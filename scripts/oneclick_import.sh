#!/usr/bin/env bash
# One-click import for Kibana 8.15+: creates data view, 2 legacy metrics, 4 Lens and final dashboard.
set -euo pipefail
KIBANA_URL="${1:-http://localhost:5601}"
FILE="${2:-finops_oneclick_package.ndjson}"
echo "[*] Importing package to $KIBANA_URL ..."
curl -k -sS -X POST "$KIBANA_URL/api/saved_objects/_import?overwrite=true"   -H "kbn-xsrf: true"   --form file=@"$FILE"
echo
echo "[*] Done. Open dashboard:"
echo "    $KIBANA_URL/app/dashboards#/view/dash-finops-oneclick-v1"
