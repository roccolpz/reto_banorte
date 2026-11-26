# Registro: simulacro de DR en us-east4 (2026-11-25)

Criterio de aceptación: el simulacro de DR restaura Cloud SQL y un workload de GKE en us-east4 dentro del RTO.
Metas (ADR 0014-j): **RPO ≤ 15 min, RTO ≤ 4 h**. Runbook: [dr-failover-cloudsql.md](../runbooks/dr-failover-cloudsql.md).

## Resultado

| Medida | Meta | Medido |
|---|---|---|
| RPO (retraso de la réplica antes de promover) | ≤ 15 min | **0 s** (`replica_lag` en 0 los 10 min previos) |
| Promoción de Cloud SQL | | **57 s** (01:42:07 → 01:43:04 UTC) |
| Workload de GKE disponible en us-east4 | | **6 s** desde el `kubectl create` (02:20:57 → 02:21:03 UTC) |
| RTO de reloj, del inicio al workload respondiendo | ≤ 4 h | **39 min** (01:42:07 → 02:21:03 UTC) |

Casi todo el RTO de reloj se fue en corregir la firma de imágenes de prod (abajo). Sin ese defecto, el tiempo técnico
es de unos 2 minutos.

## Cloud SQL

- Antes: `acme-prod-data-sql-d216` (us-central1, primaria) y `acme-prod-data-sql-d216-dr` (us-east4, `READ_REPLICA_INSTANCE`).
- `gcloud sql instances promote-replica acme-prod-data-sql-d216-dr --project acme-prod-346e`
- Después: `acme-prod-data-sql-d216-dr` queda como `CLOUD_SQL_INSTANCE`, `RUNNABLE`, en us-east4, IP privada 10.30.129.3.

## GKE en el clúster DR

Clúster `acme-prod-app-gke-dr` (us-east4-a, 1.36.4-gke.2377000, endpoint solo privado, Binary Authorization).

1. Acceso: se habilitó temporalmente el endpoint DNS (`--enable-dns-access`), que sigue protegido por IAM, y se volvió
   a deshabilitar al terminar (`allowExternalTraffic: False`).
2. Imagen sin firmar: `kubectl run --image=nginx:1.27` → **rechazada** por Binary Authorization
   (`denied by attestor ... acme-prod-qa-approved`).
3. Imagen firmada: `us-docker.pkg.dev/cloudrun/container/hello@sha256:9654eb…` agregada a `release/prod-images.txt`
   (PR #15) y firmada por `attest-prod`
   ([run](https://github.com/roccolpz/reto_banorte/actions/runs/45737475403)).
4. `Deployment` + `Service` `hello` en el namespace `dr-drill`: pod `Running` en el nodo
   `gke-acme-prod-app-gke-dr-default-f3a2f103-l178`, y la respuesta del servicio incluye `"region":"us-east4-a"`.
5. Limpieza: se borró el namespace `dr-drill`.

## Defecto encontrado: la firma de imágenes de prod nunca había funcionado

El primer uso real de `attest-prod` falló por permisos de `sa-binauthz-attestor-prod`:

| PR | Causa | Corrección |
|---|---|---|
| #16 | faltaba `containeranalysis.notes.listOccurrences` | primer intento en 2-security; el apply falló (esa SA no administra el IAM de la nota) |
| #17 | igual | `roles/containeranalysis.notes.occurrences.viewer` en 1-org, junto a `attacher` y `occurrences.editor`; revierte #16 |
| #18 | `attestations create --validate` pide `attestors.verifyImageAttested` | `attestorsViewer` → `attestorsVerifier` en 2-security (ADR 0022-k actualizado) |

## Estado después del simulacro

- La réplica promovida ya no coincide con Terraform: `drift` la reportará en `5-workloads/prod` hasta reconstruir.
- Para volver a la topología normal: `destroy` y `apply` de `5-workloads/prod` (lo que se hace al cerrar cada sesión de
  trabajo), o el paso 5 del runbook si hubiera datos que conservar.
