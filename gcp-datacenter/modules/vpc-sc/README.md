# Módulo `vpc-sc`

Crea un perímetro regular de VPC Service Controls en una política de Access Context Manager existente.
Soporta dos modos:

- `enforce = true`: la configuración va en `status` y se aplica.
- `enforce = false`: la configuración va en `spec` con `use_explicit_dry_run_spec = true`. Solo se registran
  las violaciones en Cloud Logging; nada se bloquea. Es el modo recomendado para empezar.

El default es `enforce = false` (CONTRATO §8).

- Ingreso: `ingress_identities` produce una regla que permite a esas identidades todos los servicios y recursos del
  perímetro desde cualquier origen (las SAs de Terraform que despliegan dentro).
- Egreso: cada elemento de `egress_rules` produce una regla explícita (Fase 3 §5.2) con sus identidades, sus
  proyectos destino (`projects/<número>`, nunca `*`) y sus servicios. Sin reglas, nada sale del perímetro.

El módulo no recibe `labels`: el perímetro no admite etiquetas (ADR 0012-g).

## Proyectos miembro y `ignore_changes`

El perímetro ignora cambios en `status[0].resources` y `spec[0].resources`. `member_projects` solo se usa al crear
el perímetro. Los proyectos se agregan después desde otra raíz (4-projects en prod, 2-security en dev y qa; ADR 0007-f):

| Modo | Recurso |
|---|---|
| aplicado | `google_access_context_manager_service_perimeter_resource` |
| dry-run | `google_access_context_manager_service_perimeter_dry_run_resource` |

Al pasar de dry-run a aplicado, 4-projects debe cambiar sus recursos de `*_dry_run_resource` a `*_perimeter_resource`:
los proyectos del `spec` no se copian solos al `status`.

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
| enforce | `true` aplica (`status`); `false` dry-run (`spec`). | `bool` | `false` | no |
| ingress_identities | Identidades con ingreso a todos los servicios. | `list(string)` | `[]` | no |
| egress_rules | Reglas de egreso `{ identities, resources = ["projects/<n>"], services }`. | `list(object)` | `[]` | no |

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
  restricted_services = ["storage.googleapis.com", "sqladmin.googleapis.com"]
  ingress_identities  = ["serviceAccount:sa-tf-plan@acme-bootstrap-seed-ab12.iam.gserviceaccount.com"]
  egress_rules = [{
    identities = ["serviceAccount:app-workload@acme-dev-app-ab12.iam.gserviceaccount.com"]
    resources  = ["projects/222222222222"] # proyecto común de respaldo
    services   = ["storage.googleapis.com"]
  }]
}
```

Ejemplo completo en [`examples/basic`](examples/basic/main.tf). Pruebas: `terraform test` en este directorio.
