# Módulo `observability`

Observabilidad básica de un entorno: canal de notificación por correo y alertas de CPU de nodos GKE, CPU de Cloud SQL y
túnel VPN caído (`vpn.googleapis.com/tunnel_established < 1` durante 5 minutos). Opcionalmente crea un uptime check
HTTPS y una métrica basada en logs.

Las alertas solo ven métricas de los proyectos del metrics scope de `project_id`. Por eso `monitored_project_ids`
agrega, por ejemplo, el proyecto de datos (Cloud SQL) y el del hub (túneles VPN). Quien aplica el módulo necesita
`monitoring.metricsScopes.link` en `project_id` y en cada proyecto monitoreado: `roles/monitoring.metricsScopesAdmin` en ambos
(viewer y editor no lo incluyen).

## Uso

```hcl
module "observability" {
  source                = "../../modules/observability"
  project_id            = "acme-dev-app-xxxx"
  name_prefix           = "acme-dev"
  notification_email    = "noc@example.com"
  monitored_project_ids = ["acme-dev-data-xxxx", "acme-common-net-hub-xxxx"]
  labels                = { env = "dev", app = "landing-zone", owner = "plataforma", cost_center = "TI-001", managed_by = "terraform" }
}
```

Ejemplo completo en [examples/basic](examples/basic/main.tf).

## Entradas

| Nombre | Descripción | Tipo | Default | Requerido |
|---|---|---|---|:-:|
| project_id | Proyecto que aloja las alertas. | `string` | n/a | sí |
| name_prefix | Prefijo de nombres visibles. | `string` | n/a | sí |
| notification_email | Correo de alertas. | `string` | n/a | sí |
| monitored_project_ids | Proyectos agregados al metrics scope. | `list(string)` | `[]` | no |
| enable_gke_alert | Alerta de CPU de nodos GKE. | `bool` | `true` | no |
| enable_sql_alert | Alerta de CPU de Cloud SQL. | `bool` | `true` | no |
| enable_vpn_alert | Alerta de túnel VPN caído. | `bool` | `true` | no |
| cpu_threshold | Umbral de CPU (0-1). | `number` | `0.8` | no |
| uptime_check_host | Host del uptime check HTTPS. | `string` | `null` | no |
| log_metric | Métrica de logs `{ name, filter }`. | `object` | `null` | no |
| labels | Etiquetas obligatorias. | `map(string)` | n/a | sí |

## Salidas

| Nombre | Descripción |
|---|---|
| notification_channel_id | ID del canal de correo. |
| alert_policy_ids | IDs de las alertas por llave. |

## Pruebas

```sh
terraform init -backend=false && terraform test
```
