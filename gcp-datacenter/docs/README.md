# Guía de operación

Cómo se configura y opera el pipeline de la landing zone. Las convenciones de código están en
[CONTRATO.md](CONTRATO.md); el alcance, en [ADR 0001](adr/0001-alcance-entrega.md).

## Flujo de un cambio

1. Rama desde `main`, cambio, PR. La [plantilla](../../.github/pull_request_template.md) pide revisar el plan.
2. `ci.yml` corre en el PR:
   - `fmt`, `tflint`, `checkov` sobre todo `gcp-datacenter/`;
   - `policy-tests` (`conftest verify` y los planes de ejemplo);
   - `module-tests` (`terraform test` en cada módulo con `tests/`);
   - `validate` y `plan` en cada raíz afectada. El plan se pasa a JSON, se evalúa con las políticas y se publica
     como comentario del PR (uno por raíz, se actualiza en cada push).
3. Revisión de CODEOWNERS y todos los checks en verde. Un plan que viola una política bloquea el merge.
4. Merge a `main`: `apply.yml` aplica las raíces afectadas en orden. dev y qa solos; prod espera dos aprobaciones.
5. `drift.yml` revisa todas las raíces cada día ([drift-response](runbooks/drift-response.md)).

Diagrama: [diagrams/cicd.md](diagrams/cicd.md).

## Raíces y orden

| Orden | Raíz | Estado (prefijo) | Environment | SA (variable) |
|-------|------|------------------|-------------|---------------|
| 0 | `stages/0-bootstrap` | `0-bootstrap` | (manual, admin) | (admin) |
| 1 | `stages/1-org` | `1-org` | `prod` | `TF_SA_1_ORG` |
| 2 | `stages/2-security` | `2-security` | `prod` | `TF_SA_2_SECURITY` |
| 3 | `stages/3-networks/hub` | `3-networks/hub` | `prod` | `TF_SA_3_NETWORKS_HUB` |
| 3 | `stages/3-networks/envs/<env>` | `3-networks/<env>` | `<env>` | `TF_SA_3_NETWORKS_<ENV>` |
| 4 | `stages/4-projects/envs/<env>` | `4-projects/<env>` | `<env>` | `TF_SA_4_PROJECTS_<ENV>` |
| 5 | `stages/5-workloads/envs/<env>` | `5-workloads/<env>` | `<env>` | `TF_SA_5_WORKLOADS_<ENV>` |

Entornos en orden: dev, qa, prod. La variable de la SA sale de la llave de `stage_service_accounts`: mayúsculas y `-`
cambiado por `_` (`3-networks-prod` → `TF_SA_3_NETWORKS_PROD`).

`stages/test-orchestration` es legado con estado local: CI la valida, pero no la planea ni la aplica.

## Variables de GitHub

Settings > Secrets and variables > Actions > Variables (variables de repositorio, no secretos: ninguna es una
credencial). Los valores salen de `0-bootstrap` ([bootstrap-first-apply](runbooks/bootstrap-first-apply.md), paso 3).

| Variable | Uso |
|----------|-----|
| `WIF_PROVIDER` | Proveedor de Workload Identity Federation (`projects/<n>/locations/global/workloadIdentityPools/<pool>/providers/<prov>`) |
| `TF_STATE_BUCKET` | Bucket del estado; también llega a Terraform como `TF_VAR_state_bucket` |
| `TF_SA_PLAN` | SA de solo lectura para el plan de los PR y el drift |
| `TF_SA_1_ORG` … `TF_SA_5_WORKLOADS_PROD` | Una por llave de `stage_service_accounts` (12 en total) |
| `TF_VAR_ORG_ID` | ID de la organización → `TF_VAR_org_id` |
| `TF_VAR_BILLING_ACCOUNT` | Cuenta de facturación → `TF_VAR_billing_account` |
| `TF_VAR_SUFFIX` | Sufijo de 4 caracteres hex → `TF_VAR_suffix` |
| `TF_LABELS_JSON` | Etiquetas base en JSON, p. ej. `{"app":"landing-zone","owner":"platform","cost_center":"infra"}` → `TF_VAR_labels`. Obligatoria para 1-org (sin default); vacía, las demás raíces usan su default |
| `NOTIFICATION_EMAIL` | Correo del canal de alertas → `TF_VAR_notification_email` (obligatoria en 5-workloads) |

GitHub guarda los nombres de variable en mayúsculas; los workflows los pasan a Terraform con el nombre en minúsculas.
No se usan llaves JSON ni tokens personales (ADR 0004-e).

## Environments de GitHub

Settings > Environments:

| Environment | Protección |
|-------------|------------|
| `dev` | Rama de despliegue: solo `main` |
| `qa` | Rama de despliegue: solo `main` |
| `prod` | Rama de despliegue: solo `main`; **Required reviewers** con los responsables de plataforma y seguridad |

GitHub pide una sola aprobación de la lista de reviewers del environment, no dos. Para las dos aprobaciones de
la especificación, agregar al menos dos reviewers con "Prevent self-review" activado (quien hace el merge no
cuenta) o un segundo environment de puerta. En un repositorio privado, los reviewers y la protección de `main`
requieren GitHub Pro (gratis con GitHub Student Developer Pack) o hacer público el repositorio.

Las SA `*-prod` y las de las etapas comunes (`1-org`, `2-security`, `3-networks-hub`) solo aceptan tokens emitidos
para el environment `prod` (condición de WIF en `0-bootstrap`): un job fuera de ese environment no puede impersonarlas
aunque tenga la variable. Por eso esas tres raíces corren en `prod` y esperan las dos aprobaciones.

Cada job de prod (comunes, red, proyectos, cargas) pide aprobación por separado. Para aprobar una sola vez por release, se
puede agregar un job de "puerta" en `prod` del que dependan los tres; hoy no existe.

## Protección de `main`

Settings > Branches > Branch protection rules > `main`:

- Require a pull request before merging, 1 aprobación mínima, "Require review from Code Owners".
- Require status checks to pass: `fmt`, `tflint`, `checkov`, `policy-tests`, y los jobs de matriz `validate` y
  `plan` (y `module-tests` cuando haya módulos con pruebas).
- Require branches to be up to date before merging.
- Do not allow bypassing the above settings.
- Sin push directo ni force push.

[CODEOWNERS](../../.github/CODEOWNERS) es una plantilla comentada: reemplaza los equipos y quita el `#`.

## Herramientas fijadas

| Herramienta | Versión | Dónde |
|-------------|---------|-------|
| Terraform | 1.17.2 | `ci.yml`, `.github/actions/tf-init` |
| tflint | v0.66.0, ruleset google 0.41.0 | `ci.yml`, `.tflint.hcl` |
| checkov | acción v12.3139.0 (checkov 3.4.3) | `ci.yml`, `.checkov.yaml` |
| conftest | v0.71.1 (SHA-256 verificado) | `.github/actions/setup-conftest` |

Todas las acciones de terceros están fijadas a un commit SHA completo con la versión en un comentario. Para
actualizar, cambia el SHA y el comentario en el mismo PR.

Omisiones de checkov: cada una tiene su motivo en [`.checkov.yaml`](../.checkov.yaml). Agregar una omisión requiere
revisión de seguridad.

## Comprobación local

```bash
gcp-datacenter/scripts/validate-all.sh          # fmt, validate y terraform test, sin credenciales
gcp-datacenter/scripts/discover-roots.sh roots  # raíces que ve CI
```

Detalle de las capas de prueba: [tests/README.md](../tests/README.md).

## Runbooks

- [Primer apply y migración del estado de bootstrap](runbooks/bootstrap-first-apply.md)
- [Primer despliegue en una organización de prueba](runbooks/despliegue-org-prueba.md)
- [Agregar un entorno o un proyecto de aplicación](runbooks/add-environment.md)
- [Túnel VPN o BGP caído](runbooks/vpn-down.md)
- [Failover de Cloud SQL a us-east4](runbooks/dr-failover-cloudsql.md)
- [Rotar un secreto o una llave](runbooks/rotate-secret.md)
- [Destruir dev](runbooks/destroy-dev.md)
- [Responder a un issue de drift](runbooks/drift-response.md)

## Decisiones

- [ADR 0001: alcance de la entrega](adr/0001-alcance-entrega.md)
- [ADR 0003-e: etapas con un estado GCS por etapa y entorno](adr/0003-e-etapas-y-backend-gcs.md)
- [ADR 0004-e: Workload Identity Federation sin llaves](adr/0004-e-wif-sin-llaves.md)
- [ADR 0005-e: on-prem simulado con HA VPN](adr/0005-e-onprem-simulado-ha-vpn.md)
- [ADR 0006-e: VPC Service Controls en dry-run](adr/0006-e-vpc-sc-dry-run.md)
