# firewall

Reglas de firewall de VPC para una red de entorno. Acepta reglas propias (`rules`) y, con
`default_rules = true`, crea el juego base que pide el diseño (Fase 3, §4.3):

| Regla | Prioridad | Acción | Origen |
|---|---|---|---|
| `deny-other-envs` | 900 | deny all, con logging | `deny_source_cidrs` (rangos de los otros entornos) |
| `allow-iap` | 1000 | allow tcp 22, 3389 | `35.235.240.0/20` |
| `allow-health-checks` | 1000 | allow tcp | `130.211.0.0/22`, `35.191.0.0/16` |
| `allow-onprem` | 1000 | allow all | `onprem_cidrs` (`192.168.0.0/16`) |
| `deny-all-ingress` | 65000 | deny all, con logging | `0.0.0.0/0` |

Cada regla se llama `<name_prefix>-fw-<llave>`.

## Uso

```hcl
module "firewall" {
  source            = "../../modules/firewall"
  project_id        = "acme-dev-net-host-xxxx"
  network           = module.spoke.network_self_link
  name_prefix       = "acme-dev-net"
  default_rules     = true
  deny_source_cidrs = ["10.20.0.0/16", "10.30.0.0/16", "10.31.0.0/16"]
  labels            = local.labels
}
```

Ejemplo completo: [examples/basic](examples/basic/main.tf).

<!-- BEGIN_TF_DOCS -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_id | Proyecto dueño de la VPC. | `string` | n/a | yes |
| network | Self link o nombre de la VPC. | `string` | n/a | yes |
| name_prefix | Prefijo de los nombres de regla. | `string` | n/a | yes |
| labels | Etiquetas obligatorias (se validan; las reglas no aceptan etiquetas). | `map(string)` | n/a | yes |
| default_rules | Crea el juego base del entorno. | `bool` | `false` | no |
| onprem_cidrs | Rangos on-prem permitidos. | `list(string)` | `["192.168.0.0/16"]` | no |
| deny_source_cidrs | Rangos de otros entornos a bloquear. | `list(string)` | `[]` | no |
| rules | Reglas adicionales (`direction`, `action`, `priority`, `ranges`, `protocols`, `target_tags`, `enable_logging`). | `map(object)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| rule_names | Llave de regla -> nombre. |
| rule_self_links | Llave de regla -> self link. |
<!-- END_TF_DOCS -->

## Pruebas

```bash
terraform init -backend=false && terraform test
```
