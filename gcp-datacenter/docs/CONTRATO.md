# Contrato de etapas y convenciones

Fuente de verdad para quien implemente cualquier etapa o módulo. Base: la especificación del reto
(`RETO-Implementación-DataCenter-SandboxAI-Terraform-2.pdf`) y el documento de Fase 3 (`Fase3-EQ5-14-3.pdf`).
El alcance de la entrega está en [ADR 0001](adr/0001-alcance-entrega.md).

Si una decisión de este contrato resulta imposible en GCP, se documenta en un ADR nuevo en `docs/adr/`
y se avisa en el reporte; no se cambia en silencio.

## 1. Estructura

```
gcp-datacenter/
├── modules/<modulo>/        main.tf, variables.tf, outputs.tf, versions.tf, README.md,
│                            examples/basic/main.tf, tests/<modulo>.tftest.hcl
├── stages/
│   ├── 0-bootstrap/
│   ├── 1-org/
│   ├── 2-security/
│   ├── 3-networks/hub/
│   ├── 3-networks/envs/{dev,qa,prod}/
│   ├── 4-projects/envs/{dev,qa,prod}/
│   ├── 5-workloads/envs/{dev,qa,prod}/
│   └── test-orchestration/  LEGADO. No se borra (tiene estado local con recursos vivos). Debe seguir validando.
├── policies/                Conftest (rego) sobre el plan JSON
├── tests/                   e2e y notas de pruebas de integración
└── docs/                    README de operación, adr/, runbooks/, diagramas
.github/workflows/           (en la raíz del repo, no dentro de gcp-datacenter)
```

Los entornos `envs/<env>` son raíces casi idénticas: misma lógica en un módulo o en archivos iguales, cambian `locals`/defaults.
Patrón recomendado: cada `envs/<env>/main.tf` llama a un módulo local de la etapa (p. ej. `stages/5-workloads/modules/env`)
o duplica archivos pequeños; lo importante es que cada entorno tenga su propio estado.

## 2. Versiones (obligatorio)

Cada raíz tiene `versions.tf`:

```hcl
terraform {
  required_version = ">= 1.9"
  required_providers {
    google      = { source = "hashicorp/google", version = "~> 6.0" }
    google-beta = { source = "hashicorp/google-beta", version = "~> 6.0" }
    random      = { source = "hashicorp/random", version = "~> 3.6" }
  }
}
```

Los módulos declaran `google`/`google-beta` con `">= 6.0, < 7.0"`.
Cada raíz versiona su `.terraform.lock.hcl`, generado con
`terraform providers lock -platform=linux_amd64 -platform=darwin_arm64`.
Módulos propios con recursos `google_*`; no se usan módulos externos (decisión: menos riesgo de incompatibilidad con google 6.x y tests con mocks más simples).

## 3. Backend y estado remoto

Cada raíz (menos 0-bootstrap en su primer apply) tiene `backend.tf`:

```hcl
terraform {
  backend "gcs" {
    prefix = "3-networks/dev"   # <etapa>[/<env>]
  }
}
```

El bucket se pasa con `terraform init -backend-config="bucket=$TF_STATE_BUCKET"`.
Prefijos: `0-bootstrap`, `1-org`, `2-security`, `3-networks/hub`, `3-networks/<env>`, `4-projects/<env>`, `5-workloads/<env>`.
Validación local: `terraform init -backend=false && terraform validate`.

Lectura de etapas previas:

```hcl
data "terraform_remote_state" "org" {
  backend = "gcs"
  config  = { bucket = var.state_bucket, prefix = "1-org" }
}
```

Toda raíz de etapa ≥1 recibe `var.state_bucket` (string).

## 4. Nombres y etiquetas

- `var.prefix` = empresa, default `"acme"`. `var.suffix` = 4 caracteres hex que hace únicos los IDs globales (proyectos, buckets, keyrings).
- Proyectos: `<prefix>-<entorno>-<dominio>-<suffix>`: `acme-bootstrap-seed-xxxx`, `acme-common-net-hub-xxxx`,
  `acme-common-logging-xxxx`, `acme-common-security-xxxx`, `acme-common-backup-xxxx`,
  `acme-<env>-net-host-xxxx`, `acme-<env>-app-xxxx`, `acme-<env>-data-xxxx` (máx. 30 caracteres).
- Recursos: `<prefix>-<entorno>-<dominio>-<recurso>`, p. ej. `acme-prod-net-vpc`, `acme-prod-net-app-usc1`, `acme-common-net-hub-vpc`.
- Entornos válidos: `dev`, `qa`, `prod` (validar en variables). El legado `test` no existe en las etapas nuevas.
- Etiquetas obligatorias en todo recurso que las acepte (`labels`, `resource_labels`, `user_labels`):
  `env`, `app`, `owner`, `cost_center`, `managed_by = "terraform"`.
  Cada módulo recibe `var.labels` (map(string)) y **valida** que estén las 5 llaves.
  Cada raíz arma `local.labels = merge(var.labels, { env = ..., managed_by = "terraform" })`.

## 5. Regiones y direccionamiento (Fase 3, sección 4)

- Primaria `us-central1`, DR `us-east4`.
- On-prem (simulado con la VPC `onprem-sim`): `192.168.0.0/16`, subred `192.168.10.0/24` en us-central1, ASN `65001`.
- Hub: `10.0.0.0/16`; subred `10.0.0.0/24` (us-central1), `10.0.1.0/24` (us-east4). Cloud Router del hub ASN `64514`.
- Entornos (X = 10 dev, 20 qa, 30 prod us-central1, 31 prod us-east4):

| Rango | CIDR | Uso |
|---|---|---|
| app | `10.X.0.0/20` | subred primaria (VM y nodos GKE), flow logs 50 %, Private Google Access |
| services | `10.X.32.0/22` | rango secundario `services` de la subred app |
| proxy-only | `10.X.48.0/23` | subred `REGIONAL_MANAGED_PROXY` (reservada) |
| pods | `10.X.64.0/18` | rango secundario `pods` de la subred app |
| PSA | `10.X.128.0/20` | `google_compute_global_address` VPC_PEERING + `google_service_networking_connection` (solo X=10,20,30) |

- dev y qa solo en us-central1. prod en us-central1 y us-east4 (misma VPC, dos subredes app).
- Cloud NAT por región y por VPC de entorno (prod: dos).
- GKE master CIDR: dev `172.16.10.0/28`, qa `172.16.20.0/28`, prod `172.16.30.0/28`, prod DR (us-east4) `172.16.31.0/28`.
- Las variables de CIDR validan con `can(cidrhost(...))` y que no se solapen con `192.168.0.0/16`.

## 6. Salidas por etapa (interfaz entre frentes)

Nombres exactos; los consumidores dependen de ellos.

**0-bootstrap**
- `seed_project_id` (string), `state_bucket` (string), `state_kms_key` (string)
- `stage_service_accounts` (map(string)): llaves `plan`, `1-org`, `2-security`, `3-networks-hub`, `3-networks-dev`, `3-networks-qa`, `3-networks-prod`, `4-projects-dev`, `4-projects-qa`, `4-projects-prod`, `5-workloads-dev`, `5-workloads-qa`, `5-workloads-prod` → email
- `wif_provider_name` (string, `projects/<num>/locations/global/workloadIdentityPools/<pool>/providers/<prov>`)
- `bootstrap_folder_id` (string)

**1-org**
- `folder_ids` (map(string)): `bootstrap`, `common`, `dev`, `qa`, `prod` → `folders/<id>`
- `common_project_ids` (map(string)): `net_hub`, `logging`, `security`, `backup`
- `common_project_numbers` (map(string)): mismas llaves → número de proyecto (2-security lo usa como destino de egreso de VPC-SC, ADR 0013-g)
- `net_host_project_ids` (map(string)): `dev`, `qa`, `prod` (proyectos ya habilitados como Shared VPC host por 1-org NO; los habilita 3-networks)
- `audit_log_bucket` (string)
- `custom_role_ids` (map(string)): `kms_key_iam_admin`, `tag_value_iam_admin` → `organizations/<id>/roles/<nombre>` (roles mínimos para que 4-projects otorgue permisos sobre llaves y valores de etiqueta sin poder destruirlos)

**2-security**
- `kms_keys` (map(map(string))): `[env][purpose]` → id de llave; `purpose` ∈ `storage`, `sql`, `gke`; regiones: llaves us-central1; prod además `sql-dr` en us-east4 y `storage-us` en la multi-región us (ADR 0002-d)
- `secret_ids` (map(map(string))): `[env][nombre]` → id del secreto (contenedor sin versión)
- `access_policy_name` (string, número)
- `perimeter_names` (map(string)): `dev`, `qa`, `prod` → `accessPolicies/<n>/servicePerimeters/<nombre>`
- `vpc_sc_enforce` (map(bool)): `dev`, `qa`, `prod` → `true` si el perímetro está en modo aplicado (4-projects lo lee; no se declara otra vez)
- Los perímetros ignoran cambios en sus listas de recursos (`lifecycle.ignore_changes`). Los proyectos de app y datos de prod los agrega 4-projects-prod; los de dev y qa, 2-security leyendo `4-projects/<env>` (ADR 0007-f).
- Los proyectos `net-host` no entran a los perímetros VPC-SC: solo los de app y datos.

**3-networks/hub**
- `hub_project_id`, `hub_network_id`, `hub_network_self_link`, `ncc_hub_id` (strings)
- `onprem_cidrs` (list(string)), `corp_dns_domain` (string, `corp.acme.internal.`)

**3-networks/envs/<env>**
- `host_project_id`, `network_id`, `network_self_link`, `network_name` (strings)
- `subnets` (map(object)): llave = región (`us-central1`, `us-east4`) → `{ id, self_link, name, cidr, pods_range_name, services_range_name }`
- `psa_connection_id` (string), `dns_zone_name` (string), `dns_domain` (string, `<env>.gcp.acme.internal.`)
- `secure_tag_values` (map(string)): `gke-nodes`, `vm` → `tagValues/<id>` (etiquetas seguras con propósito `GCE_FIREWALL` ligadas a la VPC del entorno; las reglas de firewall apuntan a ellas)

**4-projects/envs/<env>**
- `app_project_id`, `app_project_number`, `data_project_id`, `data_project_number` (strings)
- `service_accounts` (map(string)): `gke_nodes`, `app_workload`, `vm` → email

**5-workloads/envs/<env>**
- `gke_cluster_name`, `sql_instance_name`, `sql_private_ip`, `bucket_name`, `mig_name` (strings, los que apliquen)
- `gke_dr_cluster_name` (string, solo prod; `null` en dev y qa)

## 7. Identidad y CI

- Repositorio GitHub: `roccolpz/reto_banorte` (privado). WIF acepta solo ese repositorio (`attribute_condition`).
- Las SA `*-prod` y las de `1-org`, `2-security` y `3-networks-hub` solo se pueden impersonar desde el environment `prod`
  de GitHub (`attribute.environment`). La SA `plan` no tiene esa restricción (plan de PR y drift).
- Sin llaves JSON. Sin secretos en código ni en `.tfvars`.
- Valores no secretos por raíz en `terraform.tfvars.example` (el `.gitignore` excluye `*.tfvars`).
  En CI llegan como `TF_VAR_*` desde variables de GitHub: `TF_VAR_org_id`, `TF_VAR_billing_account`, `TF_VAR_state_bucket`, `TF_VAR_suffix`.
- Raíces de etapa ≥1: `provider "google" { billing_project = <seed o proyecto propio>, user_project_override = true }` cuando el recurso lo requiera (org policies, Access Context Manager).
- Grupos humanos (Fase 3, §3.2) como variable `groups` (map(string)); si está vacía no se crean bindings, para que el apply funcione en una org sin grupos. Los grupos ordinarios solo leen; `break_glass` tiene la administración de emergencia y queda sin miembros fuera de un incidente (ADR 0009-g).

## 8. Recursos irreversibles o caros (defaults seguros)

- Retención bloqueada del bucket de auditoría: `var.audit_retention_locked`, default `false`. En la entrega real se aplica 1-org con `TF_VAR_audit_retention_locked=true` (`docs/runbooks/bootstrap-first-apply.md`). Bloquear es irreversible.
- VPC-SC: `var.vpc_sc_enforce` (map(bool) por entorno), default `false` en los tres (dry-run) para no romper el pipeline; ingreso explícito para las SA de las etapas y egreso explícito de `app_workload` al proyecto de respaldo (ADR 0013-g).
- Cloud SQL: HA y réplica DR (`var.sql_ha`, `var.enable_dr_replica`) y bucket dual-region (`var.bucket_dual_region`) con default `null`: `true` en prod, `false` en dev/qa, para que el pipeline sin tfvars no despliegue prod sin ellos.
- GKE: zonal en dev/qa, regional en prod (`var.regional`). Máquinas pequeñas por default.
- `deletion_protection` configurable; default `false` en dev/qa para que `terraform destroy` en dev limpie todo.
- Llaves KMS no se borran en GCP: los nombres de keyring llevan `suffix`.

## 9. Calidad mínima por módulo

- `variables.tf`: `description` en todas; `validation` en etiquetas, entorno, CIDR y regiones.
- `outputs.tf` con `description`.
- `README.md`: propósito, entradas, salidas, ejemplo (formato compatible con terraform-docs).
- `examples/basic/main.tf` que valida con `terraform init -backend=false && terraform validate`.
- `tests/<modulo>.tftest.hcl` con `mock_provider "google" {}` (y `google-beta` si aplica), `command = plan`,
  al menos: un caso feliz con asserts de configuración clave y un caso `expect_failures` de validación.
- `terraform fmt -recursive` limpio.
