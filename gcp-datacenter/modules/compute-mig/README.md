# Módulo `compute-mig`

Plantilla de instancia endurecida (Shielded VM con secure boot, vTPM e integrity monitoring; OS Login; sin IP externa;
SA dedicada) y un MIG regional con health check TCP y autocuración. Por defecto crea una VM `e2-micro` que sirve para
probar la conectividad privada hacia on-premises.

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
| source_image | Imagen de arranque. | `string` | `"debian-cloud/debian-12"` | no |
| target_size | Número de VM. | `number` | `1` | no |
| health_check_port | Puerto TCP del health check. | `number` | `22` | no |
| startup_script | Script de arranque. | `string` | `null` | no |
| network_tags | Etiquetas de red. | `list(string)` | `[]` | no |
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
