# project-factory

Crea un proyecto de GCP dentro de una carpeta, lo liga a la cuenta de facturación, habilita sus APIs
y, si se indica, lo adjunta como proyecto de servicio a una Shared VPC.

Lo usan `stages/0-bootstrap` (proyecto semilla), `stages/1-org` (proyectos de `common` y `net-host`),
y `stages/4-projects`.

Decisiones:

- `auto_create_network = false` por defecto: la red `default` no se crea; las redes las define `3-networks`.
- `labels` es obligatorio y valida las cinco llaves del contrato (`env`, `app`, `owner`, `cost_center`, `managed_by`).
- Las APIs no se deshabilitan al destruir (`disable_on_destroy = false`) para no romper recursos que dependan de ellas.

## Uso

```hcl
module "project" {
  source = "../../modules/project-factory"

  name                       = "acme dev app"
  project_id                 = "acme-dev-app-a1b2"
  folder_id                  = "folders/000000000000"
  billing_account            = "000000-000000-000000"
  shared_vpc_host_project_id = "acme-dev-net-host-a1b2"
  activate_apis              = ["compute.googleapis.com", "container.googleapis.com"]
  labels = {
    env = "dev", app = "landing-zone", owner = "plataforma", cost_center = "cc-0000", managed_by = "terraform"
  }
}
```

Ejemplo completo en [`examples/basic`](examples/basic/main.tf).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.9 |
| google | >= 6.0, < 7.0 |

## Resources

| Name | Type |
|------|------|
| google_project.project | resource |
| google_project_service.services | resource |
| google_compute_shared_vpc_service_project.service_project | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name | Nombre descriptivo del proyecto | `string` | n/a | yes |
| project_id | ID único del proyecto (6 a 30 caracteres, minúsculas, dígitos y guiones) | `string` | n/a | yes |
| folder_id | Carpeta contenedora (`folders/<id>` o el número) | `string` | n/a | yes |
| billing_account | ID de la cuenta de facturación | `string` | n/a | yes |
| shared_vpc_host_project_id | Proyecto host de Shared VPC; vacío para no adjuntar | `string` | `""` | no |
| activate_apis | APIs a habilitar | `list(string)` | `["compute.googleapis.com", "container.googleapis.com"]` | no |
| labels | Etiquetas; deben incluir `env`, `app`, `owner`, `cost_center`, `managed_by` | `map(string)` | n/a | sí |
| auto_create_network | Crear la red `default` | `bool` | `false` | no |
| deletion_policy | `DELETE`, `PREVENT` o `ABANDON` | `string` | `"DELETE"` | no |

## Outputs

| Name | Description |
|------|-------------|
| project_id | ID del proyecto creado |
| project_number | Número del proyecto creado |
<!-- END_TF_DOCS -->

## Pruebas

```bash
terraform init -backend=false
terraform test
```

`tests/project-factory.tftest.hcl` usa `mock_provider "google"` y `command = plan`: no toca GCP.
