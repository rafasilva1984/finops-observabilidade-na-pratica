Param(
  [string]$EsUrl = "http://localhost:9200",
  [string]$DataFile = "data/finops_bulk.ndjson"
)

function Write-Blue($msg)  { Write-Host $msg -ForegroundColor Blue }
function Write-Green($msg) { Write-Host $msg -ForegroundColor Green }
function Write-Red($msg)   { Write-Host $msg -ForegroundColor Red }

Write-Blue "[1/4] Verificando arquivo de dados: $DataFile"
if (!(Test-Path $DataFile)) { Write-Red "Arquivo não encontrado: $DataFile"; exit 1 }

Write-Blue "[2/4] Criando index template (finops-template)..."
$respTemplate = curl.exe -k -sS -o "$env:TEMP\resp_template.json" -w "%{http_code}" -X PUT `
  "$EsUrl/_index_template/finops-template" `
  -H "Content-Type: application/json" `
  --data-binary @scripts/index-template.json
if ($respTemplate -notmatch "^20[0-9]$") {
  Write-Red "Falha (HTTP $respTemplate)"
  Get-Content "$env:TEMP\resp_template.json" | Write-Host
  exit 1
} else { Write-Green "OK (HTTP $respTemplate)" }

Write-Blue "[3/4] Enviando bulk para finops-metrics ..."
$respBulk = curl.exe -k -sS -o "$env:TEMP\resp_bulk.json" -w "%{http_code}" -H "Content-Type: application/x-ndjson" `
  -X POST "$EsUrl/_bulk?refresh=true" --data-binary "@$DataFile"
if ($respBulk -match "^20[0-9]$") {
  $bulkContent = Get-Content "$env:TEMP\resp_bulk.json" -Raw
  if ($bulkContent -match '"errors":false') { Write-Green "Bulk finalizado com sucesso (HTTP $respBulk)" }
  else { Write-Red "Bulk finalizado com erros (HTTP $respBulk)"; $bulkContent.Substring(0,[Math]::Min(1500,$bulkContent.Length)) }
} else {
  Write-Red "Falha no bulk (HTTP $respBulk)"
  Get-Content "$env:TEMP\resp_bulk.json" -First 50 | Write-Host
  exit 1
}

Write-Blue "[4/4] Criando alias finops-* → finops-metrics ..."
$aliasBody = '{"actions":[{"add":{"index":"finops-metrics","alias":"finops-*"}}]}'
$respAlias = curl.exe -k -sS -o "$env:TEMP\resp_alias.json" -w "%{http_code}" -X POST `
  "$EsUrl/_aliases" -H "Content-Type: application/json" -d "$aliasBody"
if ($respAlias -notmatch "^20[0-9]$") {
  Write-Red "Falha alias (HTTP $respAlias)"
  Get-Content "$env:TEMP\resp_alias.json" | Write-Host
  exit 1
} else { Write-Green "Alias criado (HTTP $respAlias)" }

Write-Green "Concluído. Abra o Kibana em http://localhost:5601 e crie o Data View finops-* com @timestamp"
