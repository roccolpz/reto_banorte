# Módulo `vpc-sc`

Crea un perímetro regular de VPC Service Controls en una política de Access Context Manager existente.
Soporta dos modos:

- `enforce = true`: la configuración va en `status` y se aplica.
- `enforce = false`: la configuración va en `spec` con `use_explicit_dry_run_spec = true`. Solo se registran
  las violaciones en Cloud Logging; nada se bloquea. Es el modo recomendado para empezar.

Las reglas de ingreso y egreso se generan a partir de listas de identidades: cada lista produce una regla que
permite a esas identidades todos los servicios y recursos (ingreso desde cualquier origen, egreso hacia cualquier destino).

## Proyectos miembro y `ignore_changes`

El perímetro ignora cambios en `status[0].resources` y `spec[0].resources`. `member_projects` solo se usa al crear
el perímetro. Los proyectos se agregan después desde otra raíz (4-projects en prod, 2-security en dev y qa; ADR 0007-f):

| Modo | Recurso |
|---|---|
| aplicado | `google_access_context_manager_service_perimeter_resource` |
| dry-run | `google_access_context_manager_service_perimeter_dry_run_resource` |

Al pasar de dry-run a aplicado, 4-projects debe cambiar sus recursos de `*_dry_run_resource` a `*_perimeter_resource`:
los proyectos del `spec` no se copian solos al `status`.

Compatibilidad con la raíz legada `stages/test-orchestration`: el default de `enforce` es `true` para no cambiar su
perímetro vivo. Las etapas nuevas siempre pasan `enforce = var.vpc_sc_enforce` (default `false`). Desde esta versión,
cambiar `member_projects` en la raíz legada ya no modifica el perímetro.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.9 |
| google | >= 6.0, < 7.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| perimeter_name | Nombre corto del perímetro (letras, números y `_`; empieza con letra). | `string` | n/a | yes |
| access_policy_name | Número de la política de Access Context Manager. | `string` | n/a | yes |
| restricted_services | Servicios protegidos, `<api>.googleapis.com`. | `list(string)` | n/a | yes |
| member_projects | Números de proyecto iniciales (se ignoran cambios posteriores). | `list(string)` | `[]` | no |
| enforce | `true` aplica (`status`); `false` dry-run (`spec`). | `bool` | `true` | no |
| ingress_identities | Identidades con ingreso a todos los servicios. | `list(string)` | `[]` | no |
| egress_identities | Identidades con egreso hacia cualquier recurso. | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| name | `accessPolicies/<n>/servicePerimeters/<nombre>` |
| enforced | `true` si está aplicado, `false` si está en dry-run |
<!-- END_TF_DOCS -->

## Ejemplo

```hcl
module "perimeter_dev" {
  source              = "../../modules/vpc-sc"
  perimeter_name      = "acme_dev_perimeter"
  access_policy_name  = "123456789"
  enforce             = false
  restricted_services = ["storage.googleapis.com", "sqladmin.googleapis.com"]
  ingress_identities  = ["serviceAccount:sa-tf-plan@acme-bootstrap-seed-ab12.iam.gserviceaccount.com"]
}
```

Ejemplo completo en [`examples/basic`](examples/basic/main.tf). Pruebas: `terraform test` en este directorio.
