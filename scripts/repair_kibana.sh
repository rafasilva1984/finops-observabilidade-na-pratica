#!/usr/bin/env bash
# repair_kibana.sh — limpa objetos antigos e recria métricas Lens estáveis (+ novo dashboard)
set -euo pipefail

KIBANA_URL="${1:-http://localhost:5601}"

red()  { printf "\033[31m%s\033[0m\n" "$*"; }
green(){ printf "\033[32m%s\033[0m\n" "$*"; }
blue() { printf "\033[34m%s\033[0m\n" "$*"; }

api() {
  local method="$1"; shift
  local path="$1"; shift
  local data="${1:-}"
  if [[ -n "$data" ]]; then
    curl -k -sS -o /tmp/kbn_resp.json -w "%{http_code}" -X "$method" "$KIBANA_URL$path" \
      -H "kbn-xsrf: true" -H "Content-Type: application/json" -d "$data"
  else
    curl -k -sS -o /tmp/kbn_resp.json -w "%{http_code}" -X "$method" "$KIBANA_URL$path" \
      -H "kbn-xsrf: true"
  fi
}

ensure_delete() {
  local type="$1" id="$2"
  local code
  code=$(api "DELETE" "/api/saved_objects/$type/$id" "" || true)
  if [[ "$code" =~ ^20[0-9]$ ]]; then
    echo "Deleted $type/$id"
  fi
}

create_so() {
  local type="$1" id="$2" body="$3"
  blue "Creating $type/$id ..."
  ensure_delete "$type" "$id" >/dev/null 2>&1 || true
  local code
  code=$(api "POST" "/api/saved_objects/$type/$id" "$body")
  if [[ "$code" =~ ^20[0-9]$ ]]; then
    green "OK ($type/$id)"
  else
    red "Failed ($type/$id) HTTP $code"
    head -c 2000 /tmp/kbn_resp.json; echo
    exit 1
  fi
}

# 0) health
code=$(api "GET" "/api/status" "")
[[ "$code" == "200" ]] || { red "Kibana not healthy ($code)"; exit 1; }

# 1) Clean legacy/broken objects (safe to ignore errors)
echo "[Cleanup] Deleting legacy visualizations and old dashboards (if exist)..."
for oid in \
  viz-total-cost viz-cost-trend viz-sla-avg viz-pareto-lens viz-cost-by-cluster viz-inefficiency-table \
  dash-finops-visao-geral dash-finops-visao-geral-v2 dash-finops-visao-geral-lens dash-finops-visao-geral-lens-v2 \
  lens-total-cost-v2 lens-sla-avg-v2 dash-finops-visao-geral-lens-v3 \
  lens-total-cost-v2-fix lens-sla-avg-v2-fix; do
  ensure_delete visualization "$oid"
  ensure_delete lens "$oid"
  ensure_delete dashboard "$oid"
done

# 2) Ensure Data View exists
create_so "index-pattern" "finops-data-view-v2" '{"attributes":{"title":"finops-*","timeFieldName":"@timestamp"}}'

REF1='{"type":"index-pattern","id":"finops-data-view-v2","name":"indexpattern-datasource-current-indexpattern"}'
REFL='{"type":"index-pattern","id":"finops-data-view-v2","name":"indexpattern-datasource-layer-layer-1"}'

# 3) Recreate stable Lens metrics (v3) — minimal state (no labels block)
create_so "lens" "lens-total-cost-v3" '{
  "attributes":{"title":"Total Cost — Lens (v3)","visualizationType":"lnsMetric","state":{
    "adHocDataViews":{},"filters":[],"query":{"language":"kuery","query":""},
    "visualization":{"layerId":"layer-1","accessor":"col-formula"},
    "datasourceStates":{"indexpattern":{"layers":{"layer-1":{
      "columns":{"col-formula":{"columnId":"col-formula","operationType":"formula","isBucketed":false,"dataType":"number","params":{"formula":"sum(cost_day)","isFormulaBroken":false}}},
      "columnOrder":["col-formula"],"incompleteColumns":{}
    }}}}
  }},
  "references": ['"$REF1"','"$REFL"']
}'

create_so "lens" "lens-sla-avg-v3" '{
  "attributes":{"title":"SLA Observed (avg) — Lens (v3)","visualizationType":"lnsMetric","state":{
    "adHocDataViews":{},"filters":[],"query":{"language":"kuery","query":""},
    "visualization":{"layerId":"layer-1","accessor":"col-formula"},
    "datasourceStates":{"indexpattern":{"layers":{"layer-1":{
      "columns":{"col-formula":{"columnId":"col-formula","operationType":"formula","isBucketed":false,"dataType":"number","params":{"formula":"average(sla_observed_pct)","isFormulaBroken":false}}},
      "columnOrder":["col-formula"],"incompleteColumns":{}
    }}}}
  }},
  "references": ['"$REF1"','"$REFL"']
}'

# 4) Recreate the other Lenses if they exist with v2 ids; if not, create them now.

# Cost Trend (reuse or create)
create_so "lens" "lens-cost-trend-v2" '{
  "attributes":{"title":"Cost Trend — Lens","visualizationType":"lnsXY","state":{
    "adHocDataViews":{},"filters":[],"query":{"language":"kuery","query":""},
    "visualization":{"legend":{"isVisible":true,"position":"right"},"valueLabels":"hide","preferredSeriesType":"line","fittingFunction":"None",
      "axisTitlesVisibilitySettings":{"x":true,"y":true},"tickLabelsVisibilitySettings":{"x":true,"y":true},
      "labelsOrientation":{"x":0,"y":0},"gridlinesVisibilitySettings":{"x":false,"y":true},"yLeftExtent":{"mode":"full"},
      "layers":[{"layerId":"layer-1","seriesType":"line","xAccessor":"col-date","accessors":["col-sum-cost"],"yConfig":[],"layerType":"data"}]
    },
    "datasourceStates":{"indexpattern":{"layers":{"layer-1":{
      "columns":{
        "col-date":{"columnId":"col-date","operationType":"date_histogram","sourceField":"@timestamp","dataType":"date","isBucketed":true,"params":{"interval":"auto"}},
        "col-sum-cost":{"columnId":"col-sum-cost","operationType":"sum","sourceField":"cost_day","dataType":"number","isBucketed":false,"params":{}}
      },"columnOrder":["col-date","col-sum-cost"],"incompleteColumns":{}
    }}}}
  }},
  "references": ['"$REF1"','"$REFL"']
}'

# Pareto
create_so "lens" "lens-pareto-v2" '{
  "attributes":{"title":"Pareto – Top 10 by Cost — Lens","visualizationType":"lnsXY","state":{
    "adHocDataViews":{},"filters":[],"query":{"language":"kuery","query":""},
    "visualization":{"legend":{"isVisible":true,"position":"right"},"valueLabels":"hide","preferredSeriesType":"bar_horizontal","fittingFunction":"None",
      "axisTitlesVisibilitySettings":{"x":true,"y":true},"tickLabelsVisibilitySettings":{"x":true,"y":true},
      "labelsOrientation":{"x":0,"y":0},"gridlinesVisibilitySettings":{"x":false,"y":true},"yLeftExtent":{"mode":"full"},
      "layers":[{"layerId":"layer-1","seriesType":"bar_horizontal","xAccessor":"col-service","accessors":["col-sum-cost"],"yConfig":[],"layerType":"data"}]
    },
    "datasourceStates":{"indexpattern":{"layers":{"layer-1":{
      "columns":{
        "col-service":{"columnId":"col-service","operationType":"terms","sourceField":"service","dataType":"string","isBucketed":true,"params":{"size":10,"orderBy":{"type":"column","columnId":"col-sum-cost"},"orderDirection":"desc"}},
        "col-sum-cost":{"columnId":"col-sum-cost","operationType":"sum","sourceField":"cost_day","dataType":"number","isBucketed":false,"params":{}}
      },"columnOrder":["col-service","col-sum-cost"],"incompleteColumns":{}
    }}}}
  }},
  "references": ['"$REF1"','"$REFL"']
}'

# Cost by Cluster
create_so "lens" "lens-cost-by-cluster-v2" '{
  "attributes":{"title":"Cost by Cluster — Lens","visualizationType":"lnsXY","state":{
    "adHocDataViews":{},"filters":[],"query":{"language":"kuery","query":""},
    "visualization":{"legend":{"isVisible":true,"position":"right"},"valueLabels":"hide","preferredSeriesType":"bar_horizontal","fittingFunction":"None",
      "axisTitlesVisibilitySettings":{"x":true,"y":true},"tickLabelsVisibilitySettings":{"x":true,"y":true},
      "labelsOrientation":{"x":0,"y":0},"gridlinesVisibilitySettings":{"x":false,"y":true},"yLeftExtent":{"mode":"full"},
      "layers":[{"layerId":"layer-1","seriesType":"bar_horizontal","xAccessor":"col-cluster","accessors":["col-sum-cost"],"yConfig":[],"layerType":"data"}]
    },
    "datasourceStates":{"indexpattern":{"layers":{"layer-1":{
      "columns":{
        "col-cluster":{"columnId":"col-cluster","operationType":"terms","sourceField":"cluster","dataType":"string","isBucketed":true,"params":{"size":10,"orderBy":{"type":"column","columnId":"col-sum-cost"},"orderDirection":"desc"}},
        "col-sum-cost":{"columnId":"col-sum-cost","operationType":"sum","sourceField":"cost_day","dataType":"number","isBucketed":false,"params":{}}
      },"columnOrder":["col-cluster","col-sum-cost"],"incompleteColumns":{}
    }}}}
  }},
  "references": ['"$REF1"','"$REFL"']
}'

# Inefficiency table
create_so "lens" "lens-inefficiency-table-v2" '{
  "attributes":{"title":"Ranking de Ineficiência — Lens","visualizationType":"lnsDatatable","state":{
    "adHocDataViews":{},"filters":[],"query":{"language":"kuery","query":""},
    "visualization":{"layerId":"layer-1","columns":[
      {"columnId":"col-service","width":200,"hidden":false},
      {"columnId":"col-sum-cost","width":160,"hidden":false},
      {"columnId":"col-avg-cpu","width":120,"hidden":false},
      {"columnId":"col-avg-mem","width":120,"hidden":false},
      {"columnId":"col-avg-sla","width":140,"hidden":false},
      {"columnId":"col-avg-eff","width":160,"hidden":false}
    ],"rowHeight":"single","headerRowHeight":"compact"},
    "datasourceStates":{"indexpattern":{"layers":{"layer-1":{
      "columns":{
        "col-service":{"columnId":"col-service","operationType":"terms","sourceField":"service","dataType":"string","isBucketed":true,"params":{"size":50,"orderBy":{"type":"column","columnId":"col-sum-cost"},"orderDirection":"desc"}},
        "col-sum-cost":{"columnId":"col-sum-cost","operationType":"sum","sourceField":"cost_day","dataType":"number","isBucketed":false,"params":{}},
        "col-avg-cpu":{"columnId":"col-avg-cpu","operationType":"average","sourceField":"cpu_pct","dataType":"number","isBucketed":false,"params":{}},
        "col-avg-mem":{"columnId":"col-avg-mem","operationType":"average","sourceField":"mem_pct","dataType":"number","isBucketed":false,"params":{}},
        "col-avg-sla":{"columnId":"col-avg-sla","operationType":"average","sourceField":"sla_observed_pct","dataType":"number","isBucketed":false,"params":{}},
        "col-avg-eff":{"columnId":"col-avg-eff","operationType":"average","sourceField":"efficiency_score","dataType":"number","isBucketed":false,"params":{}}
      },
      "columnOrder":["col-service","col-sum-cost","col-avg-cpu","col-avg-mem","col-avg-sla","col-avg-eff"],"incompleteColumns":{}
    }}}}
  }},
  "references": ['"$REF1"','"$REFL"']
}'

# 5) New dashboard v4 — only stable Lens objects
PANELS_JSON=$(cat <<'JSON'
[
  {"panelIndex":"1","gridData":{"x":0,"y":0,"w":12,"h":6,"i":"1"},"type":"lens","id":"lens-total-cost-v3","embeddableConfig":{}},
  {"panelIndex":"2","gridData":{"x":12,"y":0,"w":24,"h":12,"i":"2"},"type":"lens","id":"lens-cost-trend-v2","embeddableConfig":{}},
  {"panelIndex":"3","gridData":{"x":0,"y":6,"w":12,"h":6,"i":"3"},"type":"lens","id":"lens-sla-avg-v3","embeddableConfig":{}},
  {"panelIndex":"4","gridData":{"x":0,"y":12,"w":18,"h":14,"i":"4"},"type":"lens","id":"lens-pareto-v2","embeddableConfig":{}},
  {"panelIndex":"5","gridData":{"x":18,"y":12,"w":18,"h":14,"i":"5"},"type":"lens","id":"lens-cost-by-cluster-v2","embeddableConfig":{}},
  {"panelIndex":"6","gridData":{"x":0,"y":26,"w":36,"h":14,"i":"6"},"type":"lens","id":"lens-inefficiency-table-v2","embeddableConfig":{}}
]
JSON
)
PANELS_ESC=$(printf '%s' "$PANELS_JSON" | tr -d '\n' | sed 's/"/\\"/g')

create_so "dashboard" "dash-finops-visao-geral-lens-v4" "{
  \"attributes\":{
    \"title\":\"FinOps – Visão Geral (Lens, v4)\",
    \"optionsJSON\":\"{\\\"useMargins\\\":true,\\\"hidePanelTitles\\\":false}\",
    \"timeRestore\":false,\"timeTo\":\"now\",\"timeFrom\":\"now-90d\",
    \"refreshInterval\":{\"pause\":true,\"value\":0},\"version\":1,
    \"panelsJSON\":\"$PANELS_ESC\"
  },
  \"references\":[
    {\"type\":\"lens\",\"id\":\"lens-total-cost-v3\",\"name\":\"panel_1\"},
    {\"type\":\"lens\",\"id\":\"lens-cost-trend-v2\",\"name\":\"panel_2\"},
    {\"type\":\"lens\",\"id\":\"lens-sla-avg-v3\",\"name\":\"panel_3\"},
    {\"type\":\"lens\",\"id\":\"lens-pareto-v2\",\"name\":\"panel_4\"},
    {\"type\":\"lens\",\"id\":\"lens-cost-by-cluster-v2\",\"name\":\"panel_5\"},
    {\"type\":\"lens\",\"id\":\"lens-inefficiency-table-v2\",\"name\":\"panel_6\"}
  ]
}"

green "OK! Abra o novo dashboard: $KIBANA_URL/app/dashboards#/view/dash-finops-visao-geral-lens-v4"
