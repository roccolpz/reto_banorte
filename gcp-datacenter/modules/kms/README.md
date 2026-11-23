# Módulo `kms`

Crea un keyring de Cloud KMS en una región y un conjunto de llaves simétricas (`GOOGLE_SYMMETRIC_ENCRYPTION`,
protección `SOFTWARE`) para CMEK, con rotación automática de 90 días por default. Opcionalmente otorga
`roles/cloudkms.cryptoKeyEncrypterDecrypter` por llave, p. ej. a los agentes de servicio de Cloud Storage,
Cloud SQL o GKE del proyecto que cifra.

## Consideraciones

- Los keyrings y las llaves **no se pueden borrar** en GCP. `terraform destroy` solo los quita del estado y programa
  la destrucción de las versiones. Por eso el nombre del keyring debe llevar el `suffix` del despliegue: un nuevo
  despliegue usa nombres nuevos.
- `prevent_destroy` no acepta variables en Terraform, así que el módulo no lo fija (dev debe poder hacer `destroy`).
  Para sacar un keyring del estado sin programar la destrucción de sus llaves, la raíz usa un bloque `removed`
  con `lifecycle { destroy = false }`.
- La rotación crea una versión nueva; los datos ya cifrados no se vuelven a cifrar. Las versiones anteriores se conservan
  para descifrar.
- `rotation_period` se valida entre 1 y 90 días.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.9 |
| google | >= 6.0, < 7.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_id | Proyecto del keyring. | `string` | n/a | yes |
| location | Región del keyring (`us-central1`, `us-east4`). | `string` | n/a | yes |
| keyring_name | Nombre del keyring (con `suffix`). | `string` | n/a | yes |
| keys | Mapa propósito → `{ rotation_period = optional("7776000s"), encrypter_decrypters = optional([]) }`. | `map(object)` | n/a | yes |
| labels | Etiquetas `env`, `app`, `owner`, `cost_center`, `managed_by`. | `map(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| keyring_id | ID del keyring |
| key_ids | Mapa propósito → ID de la llave |
<!-- END_TF_DOCS -->

## Ejemplo

```hcl
module "kms_dev" {
  source       = "../../modules/kms"
  project_id   = "acme-common-security-ab12"
  location     = "us-central1"
  keyring_name = "acme-dev-keyring-ab12"
  labels       = local.labels
  keys = {
    storage = { encrypter_decrypters = ["serviceAccount:service-111111111111@gs-project-accounts.iam.gserviceaccount.com"] }
    sql     = {}
    gke     = {}
  }
}
```

Ejemplo completo en [`examples/basic`](examples/basic/main.tf). Pruebas: `terraform test` en este directorio.
