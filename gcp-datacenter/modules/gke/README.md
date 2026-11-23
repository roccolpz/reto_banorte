# Módulo `gke`

Cluster GKE privado (nodos sin IP pública) sobre una subred de Shared VPC, con pools de nodos definidos por variable.
Zonal en dev/qa y regional en prod (`regional = true`). Activa por defecto Workload Identity, Binary Authorization
(`PROJECT_SINGLETON_POLICY_ENFORCE`), Shielded GKE Nodes y el canal `REGULAR`. Cifra los secretos de etcd con CMEK si
se pasa `database_encryption_key`.

Requisitos previos (los hace `4-projects`): rangos secundarios `pods` y `services` en la subred, `roles/compute.networkUser`
en la subred y `roles/container.hostServiceAgentUser` en el host para el agente de GKE, y permiso de cifrado del agente
de GKE sobre la llave KMS.

Compatibilidad: la raíz legada `stages/test-orchestration` llama este módulo sin `labels` ni SA de nodos; por eso
`labels` acepta un mapa vacío y, sin `node_service_account`, los nodos usan la SA por defecto con scopes mínimos.

## Uso

```hcl
module "gke" {
  source                 = "../../modules/gke"
  cluster_name           = "acme-dev-app-gke"
  project_id             = "acme-dev-app-xxxx"
  region                 = "us-central1"
  network                = "projects/acme-dev-net-host-xxxx/global/networks/acme-dev-net-vpc"
  subnetwork             = "projects/acme-dev-net-host-xxxx/regions/us-central1/subnetworks/acme-dev-net-app-usc1"
  pods_range_name        = "pods"
  services_range_name    = "services"
  master_ipv4_cidr_block = "172.16.10.0/28"
  node_service_account   = "acme-dev-gke-nodes@acme-dev-app-xxxx.iam.gserviceaccount.com"
  node_pools             = { general = { machine_type = "e2-standard-2", min_count = 1, max_count = 3 } }
  labels                 = { env = "dev", app = "landing-zone", owner = "plataforma", cost_center = "TI-001", managed_by = "terraform" }
}
```

Ejemplo completo en [examples/basic](examples/basic/main.tf).

## Entradas

| Nombre | Descripción | Tipo | Default | Requerido |
|---|---|---|---|:-:|
| cluster_name | Nombre del cluster GKE. | `string` | n/a | sí |
| project_id | Proyecto de servicio donde se crea el cluster. | `string` | n/a | sí |
| region | Región del cluster; con `regional = false` se usa `<region>-a`. | `string` | n/a | sí |
| regional | `true` cluster regional, `false` zonal. | `bool` | `false` | no |
| network | ID o self link de la VPC del host. | `string` | n/a | sí |
| subnetwork | ID o self link de la subred de nodos. | `string` | n/a | sí |
| pods_range_name | Rango secundario de pods. | `string` | `null` | no |
| services_range_name | Rango secundario de services. | `string` | `null` | no |
| master_ipv4_cidr_block | CIDR /28 del plano de control. | `string` | n/a | sí |
| master_authorized_networks | Redes autorizadas al plano de control. | `list(object({cidr_block=string, display_name=string}))` | `[]` | no |
| enable_private_endpoint | Plano de control solo con endpoint privado. | `bool` | `false` | no |
| node_pools | Pools: llave = nombre; `machine_type`, `min_count`, `max_count` (por zona si es regional). | `map(object)` | n/a | sí |
| node_service_account | Email de la SA de nodos. | `string` | `null` | no |
| release_channel | `RAPID`, `REGULAR` o `STABLE`. | `string` | `"REGULAR"` | no |
| enable_workload_identity | Activa Workload Identity. | `bool` | `true` | no |
| enable_binary_authorization | Activa Binary Authorization. | `bool` | `true` | no |
| enable_shielded_nodes | Activa Shielded GKE Nodes. | `bool` | `true` | no |
| database_encryption_key | Llave KMS para secretos de etcd. | `string` | `null` | no |
| deletion_protection | Protección contra borrado. | `bool` | `false` | no |
| labels | Etiquetas (`env`, `app`, `owner`, `cost_center`, `managed_by`). | `map(string)` | `{}` | no |

## Salidas

| Nombre | Descripción |
|---|---|
| cluster_name | Nombre del cluster. |
| cluster_id | ID del cluster. |
| location | Región o zona del cluster. |
| cluster_endpoint | Endpoint del plano de control (sensible). |
| workload_pool | Pool de Workload Identity o `null`. |

## Pruebas

```sh
terraform init -backend=false && terraform test
```
