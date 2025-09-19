#!/usr/bin/env bash
# oneclick_provision_direct.sh — cria tudo via API (sem _import), compatível com Kibana 8.15.0
# Uso: bash scripts/oneclick_provision_direct.sh [KIBANA_URL]
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
  api "DELETE" "/api/saved_objects/$type/$id" "" >/dev/null 2>&1 || true
}

create() {
  local type="$1" id="$2" body="$3"
  blue "Criando $type/$id ..."
  ensure_delete "$type" "$id"
  local code
  code=$(api "POST" "/api/saved_objects/$type/$id" "$body")
  if [[ "$code" =~ ^20[0-9]$ ]]; then
    green "OK ($type/$id)"
  else
    red "Falhou ($type/$id) HTTP $code"; head -c 2000 /tmp/kbn_resp.json; echo; exit 1
  fi
}

blue "[0/8] Checando Kibana ..."
code=$(api "GET" "/api/status" "")
[[ "$code" == "200" ]] || { red "Kibana não respondeu 200 ($code)"; exit 1; }
green "Kibana OK"

# 1) Data view
create "index-pattern" "finops-data-view" '{"attributes":{"title":"finops-*","timeFieldName":"@timestamp"}}'

# 2) Visualization: viz-total-cost  (legacy metric) — baseado no seu que funciona
create "visualization" "viz-total-cost" '{
  "attributes":{
    "title":"Total Cost (Day)",
    "visState":"{\"title\":\"Total Cost (Day)\",\"type\":\"metric\",\"params\":{\"handleNoResults\":true},\"aggs\":[{\"id\":\"1\",\"enabled\":true,\"type\":\"sum\",\"schema\":\"metric\",\"params\":{\"field\":\"cost_day\"}}]}",
    "uiStateJSON":"{}",
    "kibanaSavedObjectMeta":{"searchSourceJSON":"{\"index\":\"finops-data-view\",\"query\":{\"language\":\"kuery\",\"query\":\"\"},\"filter\":[]}"}
  },
  "references":[{"type":"index-pattern","id":"finops-data-view","name":"kibanaSavedObjectMeta.searchSourceJSON.index"}]
}'

# 3) Visualization: viz-sla-avg  (legacy metric) — baseado no seu que funciona
create "visualization" "viz-sla-avg" '{
  "attributes":{
    "title":"SLA Observed (avg)",
    "visState":"{\"title\":\"SLA Observed (avg)\",\"type\":\"metric\",\"params\":{\"handleNoResults\":true},\"aggs\":[{\"id\":\"1\",\"enabled\":true,\"type\":\"avg\",\"schema\":\"metric\",\"params\":{\"field\":\"sla_observed_pct\"}}]}",
    "uiStateJSON":"{}",
    "kibanaSavedObjectMeta":{"searchSourceJSON":"{\"index\":\"finops-data-view\",\"query\":{\"language\":\"kuery\",\"query\":\"\"},\"filter\":[]}"}
  },
  "references":[{"type":"index-pattern","id":"finops-data-view","name":"kibanaSavedObjectMeta.searchSourceJSON.index"}]
}'

# Helper for Lens refs
REF1='{"type":"index-pattern","id":"finops-data-view","name":"indexpattern-datasource-current-indexpattern"}'
REFL='{"type":"index-pattern","id":"finops-data-view","name":"indexpattern-datasource-layer-layer-1"}'

# 4) Lens: Trend (line)
create "lens" "lens-cost-trend-v815" '{
  "attributes":{
    "title":"Cost Trend — Lens",
    "visualizationType":"lnsXY",
    "state":{
      "adHocDataViews":{},"filters":[],"query":{"language":"kuery","query":""},
      "visualization":{
        "legend":{"isVisible":true,"position":"right"},
        "valueLabels":"hide","preferredSeriesType":"line","fittingFunction":"None",
        "axisTitlesVisibilitySettings":{"x":true,"y":true},
        "tickLabelsVisibilitySettings":{"x":true,"y":true},
        "labelsOrientation":{"x":0,"y":0},
        "gridlinesVisibilitySettings":{"x":false,"y":true},
        "yLeftExtent":{"mode":"full"},
        "layers":[{"layerId":"layer-1","seriesType":"line","xAccessor":"col-date","accessors":["col-sum-cost"],"yConfig":[],"layerType":"data"}]
      },
      "datasourceStates":{"indexpattern":{
        "currentIndexPatternId":"finops-data-view",
        "layers":{"layer-1":{
          "columns":{
            "col-date":{"columnId":"col-date","operationType":"date_histogram","sourceField":"@timestamp","dataType":"date","isBucketed":true,"params":{"interval":"auto"}},
            "col-sum-cost":{"columnId":"col-sum-cost","operationType":"sum","sourceField":"cost_day","dataType":"number","isBucketed":false,"params":{}}
          },
          "columnOrder":["col-date","col-sum-cost"],"incompleteColumns":{}
        }}
      }}
    }
  },
  "references": ['"$REF1"','"$REFL"']
}'

# 5) Lens: Pareto
create "lens" "lens-pareto-v815" '{
  "attributes":{
    "title":"Pareto – Top 10 by Cost — Lens",
    "visualizationType":"lnsXY",
    "state":{
      "adHocDataViews":{},"filters":[],"query":{"language":"kuery","query":""},
      "visualization":{
        "legend":{"isVisible":true,"position":"right"},
        "valueLabels":"hide","preferredSeriesType":"bar_horizontal","fittingFunction":"None",
        "axisTitlesVisibilitySettings":{"x":true,"y":true},
        "tickLabelsVisibilitySettings":{"x":true,"y":true},
        "labelsOrientation":{"x":0,"y":0},
        "gridlinesVisibilitySettings":{"x":false,"y":true},
        "yLeftExtent":{"mode":"full"},
        "layers":[{"layerId":"layer-1","seriesType":"bar_horizontal","xAccessor":"col-service","accessors":["col-sum-cost"],"yConfig":[],"layerType":"data"}]
      },
      "datasourceStates":{"indexpattern":{
        "currentIndexPatternId":"finops-data-view",
        "layers":{"layer-1":{
          "columns":{
            "col-service":{"columnId":"col-service","operationType":"terms","sourceField":"service","dataType":"string","isBucketed":true,"params":{"size":10,"orderBy":{"type":"column","columnId":"col-sum-cost"},"orderDirection":"desc"}},
            "col-sum-cost":{"columnId":"col-sum-cost","operationType":"sum","sourceField":"cost_day","dataType":"number","isBucketed":false,"params":{}}
          },
          "columnOrder":["col-service","col-sum-cost"],"incompleteColumns":{}
        }}
      }}
    }
  },
  "references": ['"$REF1"','"$REFL"']
}'

# 6) Lens: Cost by Cluster
create "lens" "lens-cost-by-cluster-v815" '{
  "attributes":{
    "title":"Cost by Cluster — Lens",
    "visualizationType":"lnsXY",
    "state":{
      "adHocDataViews":{},"filters":[],"query":{"language":"kuery","query":""},
      "visualization":{
        "legend":{"isVisible":true,"position":"right"},
        "valueLabels":"hide","preferredSeriesType":"bar_horizontal","fittingFunction":"None",
        "axisTitlesVisibilitySettings":{"x":true,"y":true},
        "tickLabelsVisibilitySettings":{"x":true,"y":true},
        "labelsOrientation":{"x":0,"y":0},
        "gridlinesVisibilitySettings":{"x":false,"y":true},
        "yLeftExtent":{"mode":"full"},
        "layers":[{"layerId":"layer-1","seriesType":"bar_horizontal","xAccessor":"col-cluster","accessors":["col-sum-cost"],"yConfig":[],"layerType":"data"}]
      },
      "datasourceStates":{"indexpattern":{
        "currentIndexPatternId":"finops-data-view",
        "layers":{"layer-1":{
          "columns":{
            "col-cluster":{"columnId":"col-cluster","operationType":"terms","sourceField":"cluster","dataType":"string","isBucketed":true,"params":{"size":10,"orderBy":{"type":"column","columnId":"col-sum-cost"},"orderDirection":"desc"}},
            "col-sum-cost":{"columnId":"col-sum-cost","operationType":"sum","sourceField":"cost_day","dataType":"number","isBucketed":false,"params":{}}
          },
          "columnOrder":["col-cluster","col-sum-cost"],"incompleteColumns":{}
        }}
      }}
    }
  },
  "references": ['"$REF1"','"$REFL"']
}'

# 7) Lens: Inefficiency Table
create "lens" "lens-inefficiency-table-v815" '{
  "attributes":{
    "title":"Ranking de Ineficiência — Lens",
    "visualizationType":"lnsDatatable",
    "state":{
      "adHocDataViews":{},"filters":[],"query":{"language":"kuery","query":""},
      "visualization":{"layerId":"layer-1","columns":[
        {"columnId":"col-service","width":200,"hidden":false},
        {"columnId":"col-sum-cost","width":160,"hidden":false},
        {"columnId":"col-avg-cpu","width":120,"hidden":false},
        {"columnId":"col-avg-mem","width":120,"hidden":false},
        {"columnId":"col-avg-sla","width":140,"hidden":false},
        {"columnId":"col-avg-eff","width":160,"hidden":false}
      ],"rowHeight":"single","headerRowHeight":"compact"},
      "datasourceStates":{"indexpattern":{
        "currentIndexPatternId":"finops-data-view",
        "layers":{"layer-1":{
          "columns":{
            "col-service":{"columnId":"col-service","operationType":"terms","sourceField":"service","dataType":"string","isBucketed":true,"params":{"size":50,"orderBy":{"type":"column","columnId":"col-sum-cost"},"orderDirection":"desc"}},
            "col-sum-cost":{"columnId":"col-sum-cost","operationType":"sum","sourceField":"cost_day","dataType":"number","isBucketed":false,"params":{}},
            "col-avg-cpu":{"columnId":"col-avg-cpu","operationType":"average","sourceField":"cpu_pct","dataType":"number","isBucketed":false,"params":{}},
            "col-avg-mem":{"columnId":"col-avg-mem","operationType":"average","sourceField":"mem_pct","dataType":"number","isBucketed":false,"params":{}},
            "col-avg-sla":{"columnId":"col-avg-sla","operationType":"average","sourceField":"sla_observed_pct","dataType":"number","isBucketed":false,"params":{}},
            "col-avg-eff":{"columnId":"col-avg-eff","operationType":"average","sourceField":"efficiency_score","dataType":"number","isBucketed":false,"params":{}}
          },
          "columnOrder":["col-service","col-sum-cost","col-avg-cpu","col-avg-mem","col-avg-sla","col-avg-eff"],"incompleteColumns":{}
        }}
      }}
    }
  },
  "references": ['"$REF1"','"$REFL"']
}'

green "Tudo criado! Abra: $KIBANA_URL/app/dashboards#/view/dash-finops-oneclick-v1"
