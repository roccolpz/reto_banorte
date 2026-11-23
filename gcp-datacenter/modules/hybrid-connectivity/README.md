# hybrid-connectivity

HA VPN con BGP entre la VPC del hub y una VPC par en una región. Como on-prem se simula con la VPC
`onprem-sim` (ADR 0001), ambos lados son gateways HA VPN de GCP en el mismo proyecto:

- 2 gateways HA VPN (hub y par), 2 Cloud Routers (ASN `asn` = 64514 y `peer_asn` = 65001).
- 2 túneles por lado (interfaces 0 y 1), cada uno con su sesión BGP sobre un /30 de `bgp_cidrs`
  (`.1` lado hub, `.2` lado on-prem).
- Anuncio `CUSTOM`: subredes propias más `advertised_ranges` (hub: `10.0.0.0/8` y `35.199.192.0/19`,
  este último para que on-prem devuelva las respuestas del reenvío DNS de Cloud DNS).
- Con `create_ncc_spoke = true` (y `ncc_hub_id`), los túneles del hub se registran como spoke híbrido de NCC en el grupo
  `center`, con `include_import_ranges = ["ALL_IPV4_RANGES"]` y sin site-to-site.

**Secreto compartido:** se genera con `random_password` (32 caracteres, uno por par de túneles). No
aparece en código ni en `.tfvars`; solo vive en el estado de Terraform, que está en el bucket con CMEK
de 0-bootstrap. Quien pueda leer el estado puede leer el secreto: limitar el acceso al bucket.
Para rotarlo: `terraform apply -replace='module.<x>.random_password.secret[0]'`.

## Uso

```hcl
module "vpn" {
  source                 = "../../modules/hybrid-connectivity"
  project_id             = "acme-common-net-hub-xxxx"
  region                 = "us-central1"
  name                   = "acme-common-net-hub"
  peer_name              = "acme-onprem-sim"
  network                = module.hub.network_self_link
  peer_network           = google_compute_network.onprem.self_link
  advertised_ranges      = ["10.0.0.0/8", "35.199.192.0/19"]
  peer_advertised_ranges = ["192.168.0.0/16"]
  ncc_hub_id             = module.hub.ncc_hub_id
  create_ncc_spoke       = true
  labels                 = local.labels
}
```

Ejemplo completo: [examples/basic](examples/basic/main.tf).

<!-- BEGIN_TF_DOCS -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_id | Proyecto de ambas VPC (mismo que el hub de NCC). | `string` | n/a | yes |
| region | `us-central1` o `us-east4`. | `string` | n/a | yes |
| name | Prefijo de nombres del lado hub. | `string` | n/a | yes |
| peer_name | Prefijo de nombres del lado on-prem. | `string` | n/a | yes |
| network | Self link de la VPC del hub. | `string` | n/a | yes |
| peer_network | Self link de la VPC on-prem simulada. | `string` | n/a | yes |
| labels | Etiquetas obligatorias. | `map(string)` | n/a | yes |
| asn | ASN del lado hub. | `number` | `64514` | no |
| peer_asn | ASN del lado on-prem. | `number` | `65001` | no |
| advertised_ranges | Rangos extra que anuncia el hub. | `list(string)` | `[]` | no |
| peer_advertised_ranges | Rangos extra que anuncia on-prem. | `list(string)` | `[]` | no |
| bgp_cidrs | Dos /30 en 169.254.0.0/16, únicos por región. | `list(string)` | `["169.254.0.0/30", "169.254.1.0/30"]` | no |
| ncc_hub_id | Hub de NCC para el spoke híbrido. | `string` | `null` | no |
| create_ncc_spoke | Registra el spoke híbrido; un bool porque el id del hub se conoce recién en el apply. | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| tunnel_self_links | Túneles del lado hub. |
| peer_tunnel_self_links | Túneles del lado on-prem. |
| router_name | Cloud Router del hub. |
| peer_router_name | Cloud Router on-prem. |
| ncc_spoke_id | Spoke híbrido, o null. |
<!-- END_TF_DOCS -->

## Pruebas

```bash
terraform init -backend=false && terraform test
```
