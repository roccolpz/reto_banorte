# network-spoke

Shared VPC de un entorno (dev, qa o prod) según el direccionamiento del contrato (§5):

- VPC `<prefix>-<env>-net-vpc` (custom, enrutamiento global) y habilitación del proyecto como host
  de Shared VPC.
- Por región: subred app con rangos secundarios `pods` y `services`, flow logs (50 %) y Private
  Google Access; subred proxy-only (`REGIONAL_MANAGED_PROXY`, `ACTIVE`); Cloud Router y Cloud NAT
  (solo para la subred app).
- Private Service Access: `google_compute_global_address` (VPC_PEERING) y
  `google_service_networking_connection`.
- DNS: zona privada `<env>.gcp.<prefix>.internal.` y zona de peering de `corp.acme.internal.`
  hacia la VPC del hub (que la reenvía a on-prem).
- VPC spoke de NCC en el grupo `edge` del hub (topología STAR).

Permisos que no crea este módulo: la SA que aplica necesita `roles/dns.peer` sobre el proyecto del
hub para la zona de peering y permiso para crear spokes en el hub de NCC (el grupo edge auto-acepta
el proyecto, ver `network-hub`).

## Uso

```hcl
module "spoke" {
  source     = "../../modules/network-spoke"
  project_id = "acme-dev-net-host-xxxx"
  env        = "dev"
  regions = {
    us-central1 = { app_cidr = "10.10.0.0/20", services_cidr = "10.10.32.0/22", proxy_cidr = "10.10.48.0/23", pods_cidr = "10.10.64.0/18" }
  }
  psa_cidr              = "10.10.128.0/20"
  hub_network_self_link = local.hub.hub_network_self_link
  ncc_hub_id            = local.hub.ncc_hub_id
  labels                = local.labels
}
```

Ejemplo completo: [examples/basic](examples/basic/main.tf).

<!-- BEGIN_TF_DOCS -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_id | Proyecto host del entorno. | `string` | n/a | yes |
| env | `dev`, `qa` o `prod`. | `string` | n/a | yes |
| regions | Región -> `{ app_cidr, services_cidr, proxy_cidr, pods_cidr }`. | `map(object)` | n/a | yes |
| labels | Etiquetas obligatorias. | `map(string)` | n/a | yes |
| prefix | Prefijo de nombres. | `string` | `"acme"` | no |
| psa_cidr | Rango PSA; null = sin PSA. | `string` | `null` | no |
| flow_sampling | Muestreo de flow logs. | `number` | `0.5` | no |
| enable_shared_vpc_host | Habilita Shared VPC host. | `bool` | `true` | no |
| dns_domain | Dominio de la zona privada; null = `<env>.gcp.<prefix>.internal.`. | `string` | `null` | no |
| corp_dns_domain | Dominio corporativo. | `string` | `"corp.acme.internal."` | no |
| hub_network_self_link | VPC del hub para DNS peering; null = sin peering. | `string` | `null` | no |
| ncc_hub_id | Hub de NCC; null = sin spoke. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| network_id | ID de la VPC. |
| network_self_link | Self link de la VPC. |
| network_name | Nombre de la VPC. |
| subnets | Región -> `{ id, self_link, name, cidr, pods_range_name, services_range_name }`. |
| psa_connection_id | Conexión PSA, o null. |
| dns_zone_name | Zona privada del entorno. |
| dns_domain | Dominio de la zona privada. |
| ncc_spoke_id | VPC spoke, o null. |
<!-- END_TF_DOCS -->

## Pruebas

```bash
terraform init -backend=false && terraform test
```
