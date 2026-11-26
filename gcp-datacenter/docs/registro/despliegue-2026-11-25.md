# Registro: despliegue desde cero y plan sin cambios (2026-11-25)

Evidencia de dos criterios de aceptación después de destruir `5-workloads` en dev, qa y prod la noche anterior.

## Destroy previo

`terraform destroy` de `5-workloads` en los tres entornos terminó sin errores: prod 35 recursos, qa y dev 16 cada uno
(GKE, Cloud SQL con réplica, MIG, Redis, balanceador con Cloud Armor, Cloud Run y bóveda de Backup and DR). Los estados
quedaron vacíos y no quedaron recursos huérfanos en GCP. Solo siguen los rangos de acceso a servicios privados
(`*-net-psa`), que pertenecen a `3-networks`.

## Despliegue completo con un solo pipeline

- Workflow `apply`, `workflow_dispatch` sobre `main`: https://github.com/roccolpz/reto_banorte/actions/runs/45728751975
- Inicio 00:26:31 UTC, fin 01:11:48 UTC: **45 minutos** (objetivo: menos de 90), incluida la espera de las aprobaciones
  del environment `prod`.
- Puerta de QA: PR #10 con 2 aprobaciones de QA (dtdamm, LeoAvMo).
- Todos los jobs en verde: 1-org, 2-security, 3-networks (hub, dev, qa, prod), 4-projects y 5-workloads (dev, qa, prod),
  `tests-dev` y `attest-prod`.

| Etapa | Duración |
|---|---|
| 5-workloads/dev | 11 min 51 s |
| 5-workloads/qa | 11 min 24 s |
| 5-workloads/prod | 11 min 57 s |
| Resto de las raíces | menos de 1 min cada una |

## Verificación en prod

| Prueba | Resultado |
|---|---|
| Certificado administrado `8.233.70.243.nip.io` | `ACTIVE` |
| `GET https://8.233.70.243.nip.io/` | 200 |
| Inyección SQL (`?id=1' OR '1'='1`) | 403 (Cloud Armor) |
| XSS (`?q=<script>alert(1)</script>`) | 403 (Cloud Armor) |
| Cloud Run directo (`*.run.app`) | 404 (solo ingreso por el balanceador) |
| Cloud SQL `acme-prod-data-sql-d216` (us-central1) y réplica `-dr` (us-east4) | `RUNNABLE` |
| Memorystore `acme-prod-data-redis` | `READY`, 1 GB |
| GKE `acme-prod-app-gke` (us-central1) y `acme-prod-app-gke-dr` (us-east4) | `RUNNING`, 1.36.4-gke.2377000 |
| Bóveda `acme-prod-data-vault` | existe |

## Segundo plan sin cambios

- Workflow `drift` justo después del apply: https://github.com/roccolpz/reto_banorte/actions/runs/45734216348
- Las 13 raíces (0-bootstrap a 5-workloads en los tres entornos) reportan
  `No changes. Your infrastructure matches the configuration.`

## Conectividad híbrida desde prod (e2e)

`tests/e2e/connectivity.sh` desde la VM `acme-prod-app-vl59` del MIG `acme-prod-app-mig` (us-central1-f, IP 10.30.0.12),
por IAP SSH, hacia la VM on-prem simulada `acme-onprem-sim-server` (192.168.10.10) por HA VPN:

```text
PROJECT_ID=acme-prod-346e MIG_NAME=acme-prod-app-mig ONPREM_IP=192.168.10.10 tests/e2e/connectivity.sh
OK    ping a 192.168.10.10          (3/3 paquetes, 0 % pérdida, rtt promedio 2.9 ms)
OK    HTTP a 192.168.10.10:80
OK    DNS app.corp.acme.internal    (192.168.10.10, zona de reenvío corp.acme.internal)
```

La VM de prod no tiene IP externa; el tráfico va por IP privada y el nombre se resuelve con la zona de reenvío
`acme-common-net-hub-corp-fwd` hacia el DNS on-prem.
