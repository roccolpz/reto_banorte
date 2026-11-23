# network-hub

Red central del hub-and-spoke (Fase 3, §4):

- VPC `<prefix>-common-net-hub-vpc` (custom, enrutamiento global) con subredes `10.0.0.0/24`
  (us-central1) y `10.0.1.0/24` (us-east4), Private Google Access y flow logs.
- Hub de Network Connectivity Center con topología **STAR**:
  - grupo `center`: spokes híbridos (túneles HA VPN, módulo `hybrid-connectivity`);
  - grupo `edge`: VPC spokes de dev, qa y prod (módulo `network-spoke`). `spoke_projects` los acepta
    automáticamente. Los spokes edge aprenden las rutas del center (on-prem) pero no las de otros
    spokes edge, así los entornos quedan aislados entre sí.
- Zona privada de reenvío de `corp.acme.internal.` hacia los DNS on-prem.
- Inbound server policy para que on-prem resuelva nombres de GCP.

La VPC del hub no se registra como VPC spoke: NCC no lo exige para propagar las rutas de los spokes
híbridos.

## Uso

```hcl
module "hub" {
  source                = "../../modules/network-hub"
  project_id            = "acme-common-net-hub-xxxx"
  onprem_dns_target_ips = ["192.168.10.2"]
  spoke_projects        = values(local.net_host_project_ids)
  labels                = local.labels
}
```

Ejemplo completo: [examples/basic](examples/basic/main.tf).

<!-- BEGIN_TF_DOCS -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_id | Proyecto del hub. | `string` | n/a | yes |
| onprem_dns_target_ips | IPs de los DNS on-prem (al menos una). | `list(string)` | n/a | yes |
| labels | Etiquetas obligatorias. | `map(string)` | n/a | yes |
| prefix | Prefijo de nombres. | `string` | `"acme"` | no |
| subnets | Región -> CIDR. | `map(string)` | `{ us-central1 = "10.0.0.0/24", us-east4 = "10.0.1.0/24" }` | no |
| corp_dns_domain | Dominio corporativo reenviado. | `string` | `"corp.acme.internal."` | no |
| spoke_projects | Proyectos con auto-aceptación en el grupo edge. | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| network_id | ID de la VPC del hub. |
| network_self_link | Self link de la VPC del hub. |
| network_name | Nombre de la VPC del hub. |
| subnets | Región -> `{ id, self_link, name, cidr }`. |
| ncc_hub_id | ID del hub de NCC. |
| corp_forwarding_zone_name | Zona de reenvío corporativa. |
<!-- END_TF_DOCS -->

## Pruebas

```bash
terraform init -backend=false && terraform test
```
