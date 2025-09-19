#!/usr/bin/env bash
set -euo pipefail

KIBANA_URL="${KIBANA_URL:-http://localhost:5601}"
ES_URL="${ES_URL:-http://localhost:9200}"

echo "[1/5] Subindo Elasticsearch + Kibana (docker compose)..."
(cd docker && docker compose up -d)

echo "[2/5] Aguardando Kibana responder em $KIBANA_URL ..."
for i in {1..60}; do
  code=$(curl -k -s -o /dev/null -w "%{http_code}" "$KIBANA_URL/api/status" || true)
  if [[ "$code" == "200" ]]; then echo "Kibana OK"; break; fi
  sleep 2
done

echo "[3/5] Carregando dados no Elasticsearch..."
bash scripts/load_data.sh

echo "[4/5] Provisionando Data View, Lens e Dashboard via API do Kibana..."
bash scripts/provision_kibana.sh "$KIBANA_URL"

echo "[5/5] Pronto! Abra:"
echo "  - Kibana: $KIBANA_URL"
echo "  - Dashboard: $KIBANA_URL/app/dashboards#/view/dash-finops-visao-geral-lens-v2"
