# 0-bootstrap

Base de la automatización. La ejecuta una sola vez una persona del grupo `gcp-org-admins` con sus credenciales;
después todo pasa por GitHub Actions con WIF.

Crea:

- Carpeta `bootstrap` bajo la organización y el proyecto semilla `<prefix>-bootstrap-seed-<suffix>`
  (`deletion_policy = "PREVENT"`: guarda el estado de todas las etapas).
- Keyring `<prefix>-bootstrap-state-kr-<suffix>` y llave `<prefix>-bootstrap-state-key` con rotación de 90 días.
- Bucket de estado `<prefix>-bootstrap-tfstate-<suffix>` en `us-central1`: CMEK, versionado, acceso uniforme,
  prevención de acceso público forzada.
- Una SA por etapa (`sa-tf-plan`, `sa-tf-1-org`, `sa-tf-2-sec`, `sa-tf-3-net-{hub,dev,qa,prod}`,
  `sa-tf-4-proj-{dev,qa,prod}`, `sa-tf-5-wl-{dev,qa,prod}`).
- Pool WIF `<prefix>-github-pool` con proveedor OIDC `github`, que acepta solo `roccolpz/reto_banorte`.

## Permisos sobre el estado

| SA | Lectura | Escritura |
|---|---|---|
| `plan` | todo el bucket | ninguna |
| cada etapa | todo el bucket (lee salidas de etapas previas con `terraform_remote_state`) | solo `<prefijo de su etapa>/` (condición IAM sobre `resource.name`) |

Como la SA de plan no puede escribir el lock, el pipeline ejecuta `terraform plan -lock=false`.

## Impersonación desde GitHub

- SA `*-prod`, `1-org`, `2-security` y `3-networks-hub`: solo desde jobs con `environment: prod`
  (`attribute.environment == "prod"`).
- Resto, incluida `plan`: cualquier job del repositorio autorizado (el proveedor ya rechaza otros repositorios con `attribute_condition`).

## Permisos de organización que otorga esta etapa

Solo los que se necesitan antes de que exista 1-org:

- `sa-tf-1-org`: administración de organización, carpetas, creación de proyectos, org policies, firewall jerárquico, sinks.
- `sa-tf-plan`: lectura de organización, IAM, org policies y Access Context Manager.
- `roles/billing.user` en la cuenta de facturación para `sa-tf-1-org` y `sa-tf-4-proj-*` (crean proyectos).
- `roles/serviceusage.serviceUsageConsumer` en la semilla para todas (se usa como `billing_project`).

Los permisos de las etapas 2 a 5 los otorga `1-org` sobre las carpetas y proyectos que crea.

## Ejecución inicial

Requisitos de quien ejecuta: `roles/resourcemanager.organizationAdmin`, `roles/billing.admin` sobre la cuenta
de facturación y `roles/resourcemanager.folderCreator`.

```bash
cp terraform.tfvars.example terraform.tfvars   # completar valores
terraform init
terraform apply
```

## Migración del estado a GCS

El primer apply usa backend local porque el bucket aún no existe. Después:

1. Crear `backend.tf` con este contenido:

   ```hcl
   # terraform {
   #   backend "gcs" {
   #     prefix = "0-bootstrap"
   #   }
   # }
   ```

   (quitar los `#`).
2. Migrar:

   ```bash
   terraform init -migrate-state -backend-config="bucket=$(terraform output -raw state_bucket)"
   ```

3. Confirmar la copia, borrar `terraform.tfstate` local y versionar `backend.tf`.
4. Guardar en las variables del repositorio de GitHub: `TF_STATE_BUCKET` (`state_bucket`),
   el proveedor WIF (`wif_provider_name`) y los correos de `stage_service_accounts`.

## Salidas

| Nombre | Descripción |
|---|---|
| `seed_project_id` | ID del proyecto semilla |
| `state_bucket` | Bucket de estado |
| `state_kms_key` | Llave KMS del bucket |
| `stage_service_accounts` | Mapa etapa => correo de la SA |
| `wif_provider_name` | `projects/<num>/locations/global/workloadIdentityPools/<pool>/providers/github` |
| `bootstrap_folder_id` | `folders/<id>` |

## Pruebas

```bash
terraform init -backend=false
terraform test   # proveedor simulado; no toca GCP
```
