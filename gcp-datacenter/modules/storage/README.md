# Módulo `storage`

Bucket de Cloud Storage con CMEK, versionado, acceso uniforme, prevención de acceso público forzada y reglas de ciclo de
vida. Por defecto es regional en `US-CENTRAL1`. Para prod se usa un dual-region configurable
(`location = "US"`, `dual_region = ["US-CENTRAL1", "US-EAST4"]`) con turbo replication (`rpo = "ASYNC_TURBO"`).

La llave KMS debe estar en la misma ubicación que el bucket: `us-central1` para un bucket regional y el multi-región
`us` para un dual-region en `US` (ver [ADR 0002-d](../../docs/adr/0002-d-llave-bucket-dual-region.md)). El agente de
Cloud Storage del proyecto necesita `roles/cloudkms.cryptoKeyEncrypterDecrypter` sobre la llave (lo hace `4-projects`).

## Uso

```hcl
module "storage" {
  source            = "../../modules/storage"
  name              = "acme-prod-data-files-xxxx"
  project_id        = "acme-prod-data-xxxx"
  location          = "US"
  dual_region       = ["US-CENTRAL1", "US-EAST4"]
  turbo_replication = true
  kms_key_name      = "projects/.../locations/us/keyRings/.../cryptoKeys/storage-us"
  labels            = { env = "prod", app = "landing-zone", owner = "plataforma", cost_center = "TI-001", managed_by = "terraform" }
}
```

Ejemplo completo en [examples/basic](examples/basic/main.tf).

## Entradas

| Nombre | Descripción | Tipo | Default | Requerido |
|---|---|---|---|:-:|
| name | Nombre global del bucket. | `string` | n/a | sí |
| project_id | Proyecto del bucket. | `string` | n/a | sí |
| location | Región, o multi-región si hay `dual_region`. | `string` | `"US-CENTRAL1"` | no |
| dual_region | Dos regiones del dual-region configurable. | `list(string)` | `[]` | no |
| turbo_replication | `rpo = ASYNC_TURBO` (requiere dual-region). | `bool` | `false` | no |
| kms_key_name | Llave KMS por defecto. | `string` | n/a | sí |
| versioning | Versionado de objetos. | `bool` | `true` | no |
| lifecycle_rules | Reglas (`action`, `storage_class`, `age`, `num_newer_versions`, `with_state`). | `list(object)` | NEARLINE a 30 días; borra versiones archivadas más allá de 5 | no |
| force_destroy | Borra el bucket aunque tenga objetos. | `bool` | `false` | no |
| labels | Etiquetas obligatorias. | `map(string)` | n/a | sí |

## Salidas

| Nombre | Descripción |
|---|---|
| bucket_name | Nombre del bucket. |
| bucket_url | URL `gs://`. |

## Pruebas

```sh
terraform init -backend=false && terraform test
```
