# ADR 0023: servicios que faltaban de la especificación y desviaciones por costo

- Estado: aceptada
- Fecha: 2026-11-24

## Contexto

ADR 0001 dejó para una siguiente fase el balanceador HTTPS con Cloud Armor, Cloud Run, Memorystore, Filestore, Backup
and DR Service, Infracost y el presupuesto con alertas. La organización de prueba funciona con créditos limitados y el
proyecto no va a producción: cada servicio se agrega con la opción más barata que cumple la especificación.

## Decisión

Se agregan cuatro módulos y se conectan en `5-workloads/modules/env`:

| Servicio | Módulo | Entornos | Opción |
|---|---|---|---|
| Cloud Run | `modules/cloud-run` | dev, qa, prod | `min_instances = 0`, ingreso solo por el balanceador, SA dedicada `cloud-run` |
| Balanceador HTTPS global + Cloud Armor | `modules/load-balancer` | prod | `EXTERNAL_MANAGED`, certificado administrado en `<ip>.nip.io`, WAF OWASP (`sqli`, `xss`, `lfi`, `rce`) y Log4j |
| Memorystore for Redis | `modules/memorystore` | prod | `BASIC` 1 GB por acceso a servicios privados, AUTH y TLS |
| Backup and DR Service | `modules/backup-dr` | prod | bóveda + plan diario de Cloud SQL con 30 días de retención forzada; sin asociar a la instancia (ver desviaciones) |

`enable_load_balancer`, `enable_memorystore` y `enable_backup_dr` (null = solo prod) permiten encenderlos en otro
entorno.

Además:

- **Presupuesto**: `google_billing_budget` mensual de 6,000 MXN (unos 300 USD; la API exige la moneda de la cuenta de
  facturación, que es MXN) en `0-bootstrap` (lo aplica un administrador), alertas al 50, 90 y
  100 % del gasto real y al 100 % pronosticado, con los créditos excluidos para que la alerta mida el costo real.
- **Infracost**: el job `plan` de `ci.yml` estima el costo mensual del plan y lo agrega al comentario del PR. Necesita el
  secreto `INFRACOST_API_KEY`; sin él se omite y el PR no se bloquea.
- **Permisos**: 1-org da a la SA de `5-workloads-<env>` `run.admin`, `redis.admin`, `backupdr.admin` y
  `compute.securityAdmin` (crear la política de Cloud Armor) en la carpeta del entorno, y `projectIamAdmin` con una
  condición que solo le deja otorgar `roles/backupdr.cloudSqlOperator` (la cuenta de la bóveda no existe antes de crearla).
- **Acceso a Cloud Run**: `iam.allowedPolicyMemberDomains` impide dar `roles/run.invoker` a `allUsers`, así que el servicio
  usa `invoker_iam_disabled = true` y el control de acceso es el ingreso `INTERNAL_LOAD_BALANCER` más Cloud Armor.

## Desviaciones documentadas (no se despliegan)

| Requisito | Motivo | Mitigación |
|---|---|---|
| Filestore | Mínimo de 1 TiB `BASIC_HDD`, unos 200 USD al mes, más de lo que cubren los créditos | Los datos de archivos van al bucket CMEK dual-region de prod |
| Cloud IDS | Cerca de 1.5 USD por hora por endpoint, más de 1,000 USD al mes | Firewall jerárquico, políticas de firewall de red con etiquetas seguras, Cloud Armor y flow logs |
| Balanceador interno | Ninguna carga interna lo necesita todavía: GKE expone servicios con su propio balanceador interno si hace falta | Se agrega como un módulo aparte cuando exista un consumidor |
| Egreso de Cloud Run a la VPC (Direct VPC) | El servicio de ejemplo no llama a recursos privados; pedirlo obliga a dar `networkUser` al agente de Cloud Run en cada subred | Activarlo junto con la primera carga que use Cloud SQL o Redis desde Cloud Run |
| Asociar Cloud SQL al plan de Backup and DR | Cloud SQL usa CMEK y GCP no respalda una instancia CMEK en una bóveda con cifrado de Google (`BackupVault with Google-managed encryption do not support backups of Cloud SQL instances with Customer-managed encryption`). El proveedor `google` 6.x no tiene `encryption_config` en `google_backup_dr_backup_vault` (llega en 7.x) y el cifrado de una bóveda no se cambia después de crearla | Cloud SQL conserva sus respaldos automáticos, PITR y la réplica en us-east4. Al subir el proveedor a 7.x: llave `backupdr` en 2-security, bóveda nueva con CMEK y `sql_instances = { primary = ... }` en `5-workloads/modules/env` |
| Cloud Interconnect | Opcional en la especificación; no hay sitio físico (ADR 0005-e) | HA VPN con BGP |

## Consecuencias

- prod suma unos 18 USD al mes por el balanceador, unos 5 USD por Cloud Armor (política y reglas) y unos 35 USD por
  Memorystore; Backup and DR cobra por GB respaldado. Cloud Run cuesta cero en reposo.
- El certificado administrado tarda de 15 a 60 minutos en activarse después del primer apply de prod.
- Mientras la bóveda de Backup and DR tenga respaldos dentro de la retención no se puede borrar: el destroy de prod
  falla hasta que venzan. dev y qa no la tienen, así que el destroy de dev no cambia.
- Antes del primer apply de `5-workloads` con estos módulos se aplican `1-org` (APIs y roles) y `4-projects` (SA
  `cloud-run`), en ese orden; el pipeline ya respeta ese orden.
