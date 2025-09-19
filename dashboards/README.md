# Design de Painéis — FinOps

- **Data View**: `finops-*` (`@timestamp`)
- **Filtros globais**: `env:prod`, `team:*`, `cluster:*`

## Visão Geral
- Metric: `sum(cost_day)` (intervalo relativo de 30d)
- Line: `sum(cost_day)` por `@timestamp`
- Gauge: `avg(sla_observed_pct)`

## Pareto 80/20
- Top 10 por `sum(cost_day)` agrupado por `service`

## Eficiência (Heatmap)
- X: `cpu_pct` (intervals 0–100)
- Y: `cost_hour` (intervals)
- Value: `avg(efficiency_score)`

## Ranking de Ineficiência (Table)
- service | sum(cost_day) | avg(cpu_pct) | avg(mem_pct) | avg(sla_observed_pct) | avg(efficiency_score)
- Ordene por `sum(cost_day)` desc; destaque `avg(cpu_pct) < 30`

## Custo por Cluster/Time
- Pie/Treemap: `sum(cost_day)` por `cluster` ou `team`
