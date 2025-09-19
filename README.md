# 💰 FinOps na Prática com Observabilidade — Zero Deps (sem Python/jq)

Projeto didático para o canal **Observabilidade na Prática – By Rafa Silva**.
Tudo pronto para rodar **sem Python** e **sem jq**: basta Docker, curl e bash ou PowerShell.

> ⚠️ Ambiente **educacional**: sem TLS e sem autenticação; `curl -k` por padrão. **Não use em produção.**

## ✅ O que vem pronto
- `docker-compose` com Elasticsearch 8.15 e Kibana.
- Dataset **realista** já pronto em `data/finops_bulk.ndjson` (~12k documentos).
- Scripts de carga:
  - `scripts/load_data.sh` (bash, Linux/macOS/Git Bash)
  - `scripts/load_data.ps1` (PowerShell/Windows)
- Index template mapeado (`finops-template`).
- Guia de dashboards e teleprompter para a aula.

---

## ▶️ Como usar

### 1) Subir o ambiente
```bash
cd docker
docker compose up -d
```
Aguarde o Kibana em **http://localhost:5601**.

### 2) Carregar dados (escolha um)

**Bash (Linux/macOS/Git Bash):**
```bash
bash scripts/load_data.sh
```

**PowerShell (Windows):**
```powershell
.\scripts\load_data.ps1
```

### 3) Criar Data View
Kibana → *Stack Management* → *Data Views* → **Create**
- **Name:** `finops-*`
- **Time field:** `@timestamp`

---

## 📊 Dashboards (proposta de painéis)

1. **Visão Geral**
   - *Metric:* `sum(cost_day)` (mensal)
   - *Line:* `sum(cost_day)` por `@timestamp` (date histogram)
   - *Gauge:* `avg(sla_observed_pct)`

2. **Pareto 80/20**
   - *Bar horizontal:* `sum(cost_day)` por `service` (Top 10)

3. **Mapa de Eficiência**
   - *Heatmap:* X=`cpu_pct`, Y=`cost_hour`, Value=`avg(efficiency_score)`

4. **Ranking de Ineficiência**
   - *Table:* `service`, `sum(cost_day)`, `avg(cpu_pct)`, `avg(mem_pct)`, `avg(sla_observed_pct)`, `avg(efficiency_score)`

5. **Projeção de Custos**
   - *Line:* `sum(cost_day)` (últimos 30 dias) – explique extrapolação

6. **Custo por Cluster/Time**
   - *Treemap/Pie:* `sum(cost_day)` por `cluster` ou `team`

---

## 🧪 Scripts úteis
```bash
# reset (limpa índice e template)
bash scripts/reset_env.sh
```

---

## 🎤 Teleprompter da Aula
Veja `docs/teleprompter.md` para o roteiro completo da gravação.

---

## 🔐 Nota
Em produção, habilite **X-Pack Security** e certificados. Aqui mantemos simplificado para acelerar o aprendizado.
