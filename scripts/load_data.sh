#!/usr/bin/env bash
# Zero-dependency loader (no Python / no jq)
set -euo pipefail

ES_URL="${ES_URL:-http://localhost:9200}"
DATA_FILE="${1:-data/finops_bulk.ndjson}"

red()  { printf "\033[31m%s\033[0m\n" "$*"; }
green(){ printf "\033[32m%s\033[0m\n" "$*"; }
blue() { printf "\033[34m%s\033[0m\n" "$*"; }

blue "[1/4] Verificando arquivo de dados: $DATA_FILE"
[[ -f "$DATA_FILE" ]] || { red "Arquivo $DATA_FILE não encontrado."; exit 1; }

blue "[2/4] Criando index template (finops-template)..."
HTTP_CODE=$(curl -k -sS -o /tmp/resp_template.json -w "%{http_code}"   -X PUT "$ES_URL/_index_template/finops-template"   -H 'Content-Type: application/json'   --data-binary @scripts/index-template.json || true)
[[ "$HTTP_CODE" =~ ^20[0-9]$ ]] || { red "Falha (HTTP $HTTP_CODE)"; cat /tmp/resp_template.json || true; exit 1; }
green "OK (HTTP $HTTP_CODE)"

blue "[3/4] Enviando bulk para finops-metrics ..."
HTTP_CODE=$(curl -k -sS -o /tmp/resp_bulk.json -w "%{http_code}"   -H 'Content-Type: application/x-ndjson'   -X POST "$ES_URL/_bulk?refresh=true"   --data-binary @"$DATA_FILE" || true)
if [[ "$HTTP_CODE" =~ ^20[0-9]$ ]]; then
  if grep -q '"errors":false' /tmp/resp_bulk.json; then
    green "Bulk finalizado com sucesso (HTTP $HTTP_CODE)"
  else
    red "Bulk finalizado com erros (HTTP $HTTP_CODE)"
    head -c 2000 /tmp/resp_bulk.json; echo
  fi
else
  red "Falha no bulk (HTTP $HTTP_CODE)"
  head -c 2000 /tmp/resp_bulk.json; echo
  exit 1
fi

blue "[4/4] Criando alias finops-* → finops-metrics ..."
read -r -d '' ALIAS_BODY <<'JSON'
{"actions":[{"add":{"index":"finops-metrics","alias":"finops-*"}}]}
JSON
HTTP_CODE=$(curl -k -sS -o /tmp/resp_alias.json -w "%{http_code}"   -X POST "$ES_URL/_aliases"   -H 'Content-Type: application/json'   -d "$ALIAS_BODY" || true)
[[ "$HTTP_CODE" =~ ^20[0-9]$ ]] || { red "Falha alias (HTTP $HTTP_CODE)"; cat /tmp/resp_alias.json || true; exit 1; }
green "Alias criado (HTTP $HTTP_CODE)"

green "Concluído. Kibana em http://localhost:5601 → crie Data View: finops-* @timestamp"
