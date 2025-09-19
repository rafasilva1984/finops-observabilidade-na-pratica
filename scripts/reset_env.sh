#!/usr/bin/env bash
set -euo pipefail
ES_URL="${ES_URL:-http://localhost:9200}"
curl -k -X DELETE "$ES_URL/finops-metrics" || true
curl -k -X DELETE "$ES_URL/_index_template/finops-template" || true
echo "Limpeza concluída."
