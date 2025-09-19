# 📊 FinOps Observability – Dashboard Completo

Este repositório demonstra como aplicar **práticas de FinOps e Observabilidade** em um ambiente simulado com **Elasticsearch + Kibana**.  
Aqui você terá **dados realistas**, scripts de ingestão e **dashboards Lens** totalmente automatizados via API.

---

## 🎯 Objetivo

- Simular **custos de serviços** (day/hour), SLAs, CPU/Memória, eficiência, etc.  
- Visualizar métricas em **dashboards impactantes**.  
- Ensinar **FinOps + Observabilidade na prática** com dados ricos para análise.  
- Provisionar tudo via **scripts automáticos** (sem erros de import manual no Kibana).

---

## 🧱 Estrutura do Projeto

| Pasta              | Conteúdo                                                                 |
|--------------------|--------------------------------------------------------------------------|
| `docker/`          | Docker Compose para subir **Elasticsearch + Kibana**                     |
| `data/`            | Arquivos `NDJSON` com dados simulados para ingestão                      |
| `scripts/`         | Scripts de automação (`load_data.sh`, `provision_kibana.sh`, `all_in_one.sh`, `load_data.ps1`) |

---

## 🚀 Como rodar

### TL;DR – Um comando só
```bash
bash scripts/all_in_one.sh
```

No **Windows (PowerShell)**:
```powershell
powershell -ExecutionPolicy Bypass -File scripts/load_data.ps1
```

---

## ⚙️ Passos detalhados

### 1. Subir o ambiente
```bash
cd docker
docker compose up -d
```
> Isso sobe **Elasticsearch 8.x** e **Kibana 8.x**

### 2. Carregar os dados simulados
```bash
bash scripts/load_data.sh
```

### 3. Provisionar objetos no Kibana
Agora tudo é feito **via API**:
```bash
bash scripts/provision_kibana.sh http://localhost:5601
```
> O script cria automaticamente:
> - Data View `finops-data-view-v2`  
> - Visualizações Lens (Total Cost, SLA avg, Cost Trend, Pareto, Cluster Cost, Inefficiency Ranking)  
> - Dashboard **FinOps – Visão Geral (Lens, v2)**

### 4. Abrir o Dashboard
- Acesse: [http://localhost:5601](http://localhost:5601)  
- Vá em **Dashboard → FinOps – Visão Geral (Lens, v2)**  

---

## 📊 O que você verá

- **Total Cost** – métrica agregada  
- **Cost Trend** – evolução temporal  
- **SLA Observed (avg)** – SLA médio observado  
- **Pareto – Top 10 Services by Cost** – análise 80/20 dos custos  
- **Cost by Cluster** – comparação entre clusters  
- **Ranking de Ineficiência** – tabela com CPU/Mem/SLA/Eficiência  

---

## 🔑 Observações importantes

- Todos os **scripts usam `-k` (ignorar SSL)** por padrão → ok em **labs**, não recomendado em produção.  
- IDs das visus e dashboards terminam com `-v2` → evitam conflito com versões anteriores.  
- As métricas agora usam **Lens Formula** (`sum(cost_day)`, `average(sla_observed_pct)`) → não quebram ao importar.  

---

## 🎓 Próximos passos

- Adicionar **Heatmap de Eficiência** e filtro global `env:prod` no dashboard.  
- Integrar com **outros datasets** (Cloud billing, logs reais).  
- Publicar como aula do curso **Observabilidade na Prática**.

---

👉 Agora está 100% reproduzível: basta rodar `all_in_one.sh` que o ambiente sobe, dados são carregados e dashboard aparece pronto no Kibana.
