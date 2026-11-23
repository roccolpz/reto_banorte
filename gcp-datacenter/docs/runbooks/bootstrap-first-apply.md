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
| `AUDIT_RETENTION_LOCKED` | opcional; vacío = `true` (bloquea la retención de auditoría, ver abajo). `false` solo en organizaciones de prueba |
| `TF_SA_TERRATEST`, `TEST_FOLDER_ID`, `TEST_BILLING_ACCOUNT`, `TEST_ACCESS_POLICY` | solo para la corrida nocturna de Terratest (`runbooks/terratest.md`) |

Este comando imprime las variables `TF_SA_*` listas para copiar:

```bash
terraform output -json stage_service_accounts |
  jq -r 'to_entries[] | select(.key != "plan") | "TF_SA_\(.key | ascii_upcase | gsub("-"; "_"))=\(.value)"'
```

Crea los environments `dev`, `qa` y `prod` (ver `docs/README.md`, sección Environments).

## 4. Rol de administración de facturación (a mano)

Terraform no otorga `roles/billing.admin`: la SA de 1-org solo tiene `billing.user`. Una persona con
`billing.admin` en la cuenta lo concede al grupo `gcp-billing-admins` en la consola
(Billing > Account management > Add principal) o con:

```bash
gcloud billing accounts add-iam-policy-binding <BILLING_ACCOUNT> \
  --member="group:gcp-billing-admins@<dominio>" --role="roles/billing.admin"
```

## 5. Activar Security Command Center (a mano, antes de 1-org)

Terraform no puede activar SCC en la organización (ADR 0010-g). Si no está activo, el apply de 1-org falla al crear
la notificación de hallazgos. Un administrador de la organización lo activa una vez en la consola: Security >
Security Command Center > Get started, a nivel organización, nivel Standard (Premium es una contratación aparte).
Comprueba que la página de SCC de la organización muestre hallazgos o el resumen de activos antes de seguir.

## 6. Resto de etapas

Opción A, por el pipeline: ejecuta el workflow `apply` con "Run workflow" (aplica todas las raíces en orden).
Aprueba los jobs de prod cuando lleguen; las etapas comunes también corren en `prod`.
Al terminar, vuelve a ejecutarlo (o solo 2-security). La primera corrida de 2-security no encuentra el estado de
`4-projects/<env>` y omite lo que depende de él. La segunda crea:

- los proyectos de app y datos de dev y qa dentro de sus perímetros (ADR 0007-f);
- `secretAccessor` de `app_workload` y `vm` sobre los secretos de cada entorno, y la regla de egreso de cada
  perímetro hacia el proyecto `backup` (ADR 0013-g).

Hasta esa segunda corrida, las cargas no leen secretos. Repite 2-security cada vez que crees o recrees
`4-projects` de un entorno.

Opción B, a mano (si el pipeline todavía no está listo), en este orden, con
`terraform init -backend-config="bucket=$BUCKET"` y `terraform apply` en cada raíz:

1. `1-org`
2. `2-security`
3. `3-networks/hub`
4. `3-networks/envs/dev`, `4-projects/envs/dev`, `5-workloads/envs/dev`
5. lo mismo para `qa`
6. lo mismo para `prod`
7. `2-security` otra vez: perímetros de dev y qa, accesores de secretos y egreso de los tres entornos
   (ADR 0007-f y 0013-g).

Cada raíz de etapa ≥1 recibe `state_bucket` (`export TF_VAR_state_bucket=$BUCKET`).

Lectura del estado: en el pipeline, cada SA de etapa solo lee los prefijos que consume, listados en
`local.state_read_prefixes` de `stages/0-bootstrap/main.tf` (ADR 0008-g); la SA de plan lee todo. Un 403 al leer
el estado de otra etapa significa que falta el prefijo en esa lista: agrégalo y aplica 0-bootstrap a mano.

En la opción B, exporta también `TF_VAR_audit_retention_locked=true` antes de aplicar `1-org` (ver abajo).

### Primer apply de `3-networks/hub`: la IP del forwarder DNS

El hub lee la IP que GCP reserva para la política DNS entrante de `onprem-sim` (propósito `DNS_RESOLVER`). En el
primer apply esa IP a veces todavía no existe y el apply se detiene en la postcondición con el mensaje
"GCP aún no reservó la IP DNS_RESOLVER del forwarder entrante de onprem-sim…". No es un error de configuración:

1. Espera un minuto.
2. Vuelve a correr el apply de `3-networks/hub` (en el pipeline: "Re-run failed jobs"; a mano: `terraform apply`).

Si falla otra vez después de unos minutos, define `onprem_dns_target_ips` con la IP del DNS de on-prem y aplica
(ver "Riesgos abiertos" en `stages/3-networks/README.md`).

### Firewall de los entornos

Cada entorno usa una política de firewall de red con etiquetas seguras `gke-nodes` y `vm`, no reglas de VPC.
On-prem (`192.168.0.0/16`) solo puede iniciar conexiones TCP 80 y 443 hacia esas cargas, con logging. Una VM o
nodo sin etiqueta no recibe ingreso. La tabla completa de reglas está en `stages/3-networks/README.md`.

### Retención de auditoría bloqueada (1-org)

El pipeline (`_tf-apply.yml`, `ci.yml` y `drift.yml`) pasa `TF_VAR_audit_retention_locked=true` a 1-org, así que
el primer apply por el pipeline bloquea la retención del bucket de auditoría. En Terraform el default sigue en
`false` para que un apply a mano en una organización de prueba no lo bloquee por accidente.

Es irreversible: el bucket de auditoría no se puede borrar ni acortar su retención hasta que venza (contrato §8).

- **Entrega real:** no definas `AUDIT_RETENTION_LOCKED` (vacío = `true`). En la opción B, exporta
  `TF_VAR_audit_retention_locked=true` antes del apply de `1-org`.
- **Organización de prueba que se va a destruir:** define la variable del repositorio
  `AUDIT_RETENTION_LOCKED=false` antes del primer apply. Cambiarla después no desbloquea un bucket ya bloqueado.

## 7. Comprobar

- Un segundo `plan` en cada raíz dice `No changes.`
- `tests/e2e/connectivity.sh` pasa contra prod.

## Retroceso

Si la migración del paso 2 falla, el estado local sigue intacto: borra `backend.tf`, corre `terraform init -reconfigure`
y vuelve a intentar. No borres el estado local hasta ver el plan sin cambios.
