# firewall

Política de firewall de red (`google_compute_network_firewall_policy`) asociada a una VPC, con sus
reglas y, opcionalmente, las etiquetas seguras a las que apuntan (Fase 3, §4.3; reto: "reglas por
etiqueta segura").

- `secure_tags` crea una llave de etiqueta `<name_prefix>-fw` con propósito `GCE_FIREWALL` ligada a la
  VPC (`purpose_data.network = <proyecto>/<red>`) y un valor por elemento (p. ej. `gke-nodes`, `vm`).
- Cada regla de `rules` con `target_tags` aplica solo a las instancias que llevan esos valores; sin
  `target_tags` aplica a toda la VPC (útil para los deny).
- En una política las prioridades no se repiten; la variable lo valida.
- La política se evalúa después de las reglas de firewall de VPC (orden por defecto de GCP). Las
  etapas no crean reglas de VPC.

El juego de reglas de cada entorno (aislamiento, on-prem, GKE, IAP, health checks) lo arma
`stages/3-networks/modules/env`, que es donde se eligen los rangos.

Quien vincula las etiquetas a VM o nodos GKE necesita `roles/resourcemanager.tagUser` sobre el valor
(lo otorga 4-projects). Quien crea la llave necesita `roles/resourcemanager.tagAdmin` en el proyecto.

## Uso

```hcl
module "firewall" {
  source      = "../../modules/firewall"
  project_id  = "acme-dev-net-host-xxxx"
  network     = module.spoke.network_self_link
  name_prefix = "acme-dev-net"
  secure_tags = ["gke-nodes", "vm"]
  labels      = local.labels

  rules = {
    allow-internal = { priority = 1000, ranges = ["10.10.0.0/16"], target_tags = ["gke-nodes", "vm"] }
  }
}
```

Ejemplo completo: [examples/basic](examples/basic/main.tf).

<!-- BEGIN_TF_DOCS -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_id | Proyecto dueño de la VPC. | `string` | n/a | yes |
| network | Self link de la VPC. | `string` | n/a | yes |
| name_prefix | Prefijo de los nombres. | `string` | n/a | yes |
| labels | Etiquetas obligatorias (se validan; la política no acepta labels). | `map(string)` | n/a | yes |
| secure_tags | Valores de etiqueta segura a crear. | `list(string)` | `[]` | no |
| rules | Reglas (`direction`, `action`, `priority`, `ranges`, `protocols`, `target_tags`, `enable_logging`). | `map(object)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| policy_id | ID de la política. |
| rule_names | Llave de regla -> nombre. |
| secure_tag_values | Nombre corto -> `tagValues/<id>`. |
<!-- END_TF_DOCS -->

## Pruebas

```bash
terraform init -backend=false && terraform test
```
