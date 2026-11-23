# Runbook: primer apply desde cero y migración del estado de 0-bootstrap

Cuándo: la organización no tiene todavía la landing zone, o se reconstruye desde cero.
Quién: un administrador de la organización (grupo `gcp-org-admins`) con `gcp-billing-admins` para la cuenta de
facturación. CI no puede hacer este paso: las SA y el WIF que usa CI los crea este mismo apply.

## Requisitos

- `gcloud` y Terraform 1.17.2 instalados.
- Sesión de `gcloud auth application-default login` con una cuenta que tenga, a nivel de organización:
  Organization Administrator, Folder Creator, Project Creator, Billing Account User y Security Admin.
- ID de la organización, cuenta de facturación y un sufijo de 4 caracteres hex (`openssl rand -hex 2`).

## 1. Apply de 0-bootstrap con estado local

```bash
cd gcp-datacenter/stages/0-bootstrap
cp terraform.tfvars.example terraform.tfvars   # editar org_id, billing_account, suffix
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

`terraform.tfvars` está en `.gitignore`: no se sube.

Si `backend.tf` ya existe en el directorio, renómbralo antes del primer `init` (`mv backend.tf backend.tf.off`):
el bucket todavía no existe.

## 2. Migrar el estado local al bucket

```bash
BUCKET=$(terraform output -raw state_bucket)
```

Crea `backend.tf` (o restaura `backend.tf.off`) con:

```hcl
terraform {
  backend "gcs" {
    prefix = "0-bootstrap"
  }
}
```

Migra:

```bash
terraform init -migrate-state -backend-config="bucket=$BUCKET"
```

Responde `yes` cuando pregunte si copia el estado. Comprueba:

```bash
gcloud storage ls "gs://$BUCKET/0-bootstrap/"     # debe listar default.tfstate
terraform plan                                     # debe decir "No changes."
```

Borra las copias locales solo después de ese plan sin cambios: `rm terraform.tfstate terraform.tfstate.backup`.
Confirma `backend.tf` en una rama y abre un PR para que quede versionado.

## 3. Configurar GitHub

Con las salidas de 0-bootstrap, en Settings > Secrets and variables > Actions > Variables del repositorio:

| Variable | Valor |
|----------|-------|
| `WIF_PROVIDER` | `terraform output -raw wif_provider_name` |
| `TF_STATE_BUCKET` | `terraform output -raw state_bucket` |
| `TF_SA_PLAN` | `terraform output -json stage_service_accounts \| jq -r .plan` |
| `TF_SA_<LLAVE>` | una por llave de `stage_service_accounts` (ver la tabla en `docs/README.md`) |
| `TF_VAR_ORG_ID`, `TF_VAR_BILLING_ACCOUNT`, `TF_VAR_SUFFIX` | los mismos valores del `terraform.tfvars` |
| `TF_LABELS_JSON` | `labels` del `terraform.tfvars` en JSON, p. ej. `{"app":"landing-zone","owner":"platform","cost_center":"infra"}` |
| `NOTIFICATION_EMAIL` | correo que recibe las alertas de 5-workloads |

Este comando imprime las variables `TF_SA_*` listas para copiar:

```bash
terraform output -json stage_service_accounts |
  jq -r 'to_entries[] | select(.key != "plan") | "TF_SA_\(.key | ascii_upcase | gsub("-"; "_"))=\(.value)"'
```

Crea los environments `common`, `dev`, `qa` y `prod` (ver `docs/README.md`, sección Environments).

## 4. Resto de etapas

Opción A, por el pipeline: ejecuta el workflow `apply` con "Run workflow" (aplica todas las raíces en orden).
Aprueba los jobs de prod cuando lleguen.

Opción B, a mano (si el pipeline todavía no está listo), en este orden, con
`terraform init -backend-config="bucket=$BUCKET"` y `terraform apply` en cada raíz:

1. `1-org`
2. `2-security`
3. `3-networks/hub`
4. `3-networks/envs/dev`, `4-projects/envs/dev`, `5-workloads/envs/dev`
5. lo mismo para `qa`
6. lo mismo para `prod`

Cada raíz de etapa ≥1 recibe `state_bucket` (`export TF_VAR_state_bucket=$BUCKET`).

## 5. Comprobar

- Un segundo `plan` en cada raíz dice `No changes.`
- `tests/e2e/connectivity.sh` pasa contra prod.

## Retroceso

Si la migración del paso 2 falla, el estado local sigue intacto: borra `backend.tf`, corre `terraform init -reconfigure`
y vuelve a intentar. No borres el estado local hasta ver el plan sin cambios.
