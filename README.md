# 💰 FinOps – Observabilidade na Prática

Este projeto demonstra como aplicar **FinOps** em Observabilidade usando Elasticsearch + Kibana.  
O ambiente é totalmente simulado, com geração de dados de custo, SLA e eficiência para análise.

---

## 🚀 O que este repositório entrega

- **Data View** `finops-data-view` (`finops-*`)
- **Visualizations prontas**:
  - `viz-total-cost` → Métrica com **soma de custo diário**
  - `viz-sla-avg` → Métrica com **média do SLA observado**
- **Lens prontas**:
  - `lens-cost-trend-v815` → Tendência de custos (linha no tempo)
  - `lens-pareto-v815` → Pareto dos 10 serviços mais caros
  - `lens-cost-by-cluster-v815` → Custos por cluster
  - `lens-inefficiency-table-v815` → Ranking de ineficiência (tabela com SLA, CPU, memória, eficiência)

⚠️ **Importante:** o **dashboard não é criado automaticamente** (por limitações do Kibana 8.15).  
O usuário deve **montar o dashboard manualmente** dentro do Kibana, importando as visualizações acima.

---

## 🛠️ Passo a Passo

### 1) Subir ambiente
```bash
bash scripts/all_in_one.sh
```

### 2) Provisionar objetos no Kibana
```bash
bash scripts/oneclick_provision_direct.sh http://localhost:5601
```

Isso cria **data view + visualizações** (mas não o dashboard).

### 3) Criar o Dashboard manualmente
1. No Kibana, vá em **Dashboards → Create dashboard**  
2. Clique em **Add from library**  
3. Adicione os objetos:
   - `viz-total-cost`
   - `viz-sla-avg`
   - `lens-cost-trend-v815`
   - `lens-pareto-v815`
   - `lens-cost-by-cluster-v815`
   - `lens-inefficiency-table-v815`
4. Organize os painéis conforme desejar e salve o dashboard.

---

## 📊 Resultado esperado

- Painel com visão **FinOps completa**:
  - **Total Cost** (métrica)  
  - **SLA médio** (métrica)  
  - **Tendência de custos** (linha no tempo)  
  - **Pareto top 10 serviços mais caros**  
  - **Custos por cluster**  
  - **Ranking de ineficiência**  

---

## 🔒 Observação

- Este projeto **ignora validações de certificado SSL** (`-k`) para simplificar laboratórios locais.  
- ❌ **Não usar em produção** dessa forma.

---

## 👨‍💻 Comandos úteis

### Reimportar objetos (sobrescrevendo existentes)
```bash
bash scripts/oneclick_provision_direct.sh http://localhost:5601
```

### Remover tudo
Use a API do Kibana:
```bash
curl -k -X DELETE "http://localhost:5601/api/saved_objects/index-pattern/finops-data-view" -H "kbn-xsrf: true"
curl -k -X DELETE "http://localhost:5601/api/saved_objects/visualization/viz-total-cost" -H "kbn-xsrf: true"
curl -k -X DELETE "http://localhost:5601/api/saved_objects/visualization/viz-sla-avg" -H "kbn-xsrf: true"
curl -k -X DELETE "http://localhost:5601/api/saved_objects/lens/lens-cost-trend-v815" -H "kbn-xsrf: true"
curl -k -X DELETE "http://localhost:5601/api/saved_objects/lens/lens-pareto-v815" -H "kbn-xsrf: true"
curl -k -X DELETE "http://localhost:5601/api/saved_objects/lens/lens-cost-by-cluster-v815" -H "kbn-xsrf: true"
curl -k -X DELETE "http://localhost:5601/api/saved_objects/lens/lens-inefficiency-table-v815" -H "kbn-xsrf: true"
```
