# Módulo `compute-mig`

Plantilla de instancia endurecida (familia de imagen endurecida, ver ADR 0008-i; Shielded VM con secure boot, vTPM e
integrity monitoring; OS Login; puerto serie apagado; sin IP externa; SA dedicada; etiqueta segura para el firewall) y
un MIG regional con health check TCP, autocuración y autoscaler por CPU. Por defecto mantiene una VM `e2-micro` que
sirve para probar la conectividad privada hacia on-premises.

Requisitos: el firewall de la VPC debe permitir los rangos de health check de Google (`35.191.0.0/16`,
`130.211.0.0/22`) hacia `health_check_port` (lo gestiona el módulo de firewall de 3-networks). La SA de la etapa que
aplica este módulo necesita `roles/compute.networkUser` en la subred y `roles/iam.serviceAccountUser` sobre la SA de la
VM.

## Uso

```hcl
module "mig" {
  source                = "../../modules/compute-mig"
  name                  = "acme-dev-app-probe"
  project_id            = "acme-dev-app-xxxx"
  subnetwork            = "projects/acme-dev-net-host-xxxx/regions/us-central1/subnetworks/acme-dev-net-app-usc1"
  service_account_email = "acme-dev-vm@acme-dev-app-xxxx.iam.gserviceaccount.com"
  labels                = { env = "dev", app = "landing-zone", owner = "plataforma", cost_center = "TI-001", managed_by = "terraform" }
}
```

Ejemplo completo en [examples/basic](examples/basic/main.tf).

## Entradas

| Nombre | Descripción | Tipo | Default | Requerido |
|---|---|---|---|:-:|
| name | Prefijo de nombres. | `string` | n/a | sí |
| project_id | Proyecto de servicio. | `string` | n/a | sí |
| region | Región del MIG. | `string` | `"us-central1"` | no |
| subnetwork | Subred de la Shared VPC. | `string` | n/a | sí |
| service_account_email | SA de las VM. | `string` | n/a | sí |
| machine_type | Tipo de máquina. | `string` | `"e2-micro"` | no |
| image_family | Familia de imagen endurecida (`projects/<p>/global/images/family/<f>`). | `string` | `"projects/debian-cloud/global/images/family/debian-12"` | no |
| min_replicas | Mínimo de VM del autoscaler. | `number` | `1` | no |
| max_replicas | Máximo de VM del autoscaler. | `number` | `3` | no |
| cpu_target | Uso de CPU objetivo del autoscaler (0-1). | `number` | `0.6` | no |
| health_check_port | Puerto TCP del health check. | `number` | `22` | no |
| startup_script | Script de arranque. | `string` | `null` | no |
| network_tags | Etiquetas de red. | `list(string)` | `[]` | no |
| resource_manager_tags | Etiquetas seguras (`tagKeys/ID` = `tagValues/ID`). | `map(string)` | `{}` | no |
| labels | Etiquetas obligatorias. | `map(string)` | n/a | sí |

## Salidas

| Nombre | Descripción |
|---|---|
| mig_name | Nombre del MIG. |
| instance_group | URL del grupo de instancias. |
| instance_template_id | ID de la plantilla. |
| health_check_id | ID del health check. |

## Pruebas

```sh
terraform init -backend=false && terraform test
```
