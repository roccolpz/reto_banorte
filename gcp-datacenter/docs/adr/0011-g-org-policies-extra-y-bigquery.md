# ADR 0011-g: se conservan cuatro org policies extra y bigquery en VPC-SC

- Estado: aceptada
- Fecha: 2026-11-23

## Contexto

La revisión señaló como alcance de más:

- 1-org aplica cuatro org policies que Fase 3 no lista: `compute.requireShieldedVm`,
  `storage.publicAccessPrevention`, `sql.restrictPublicIp` y `compute.skipDefaultNetworkCreation`.
- `bigquery.googleapis.com` está en `restricted_services` de los perímetros de VPC-SC.

## Decisión

Se conservan las cinco.

- `requireShieldedVm`: Fase 3 pide imágenes endurecidas para las VM de 5-workloads; la política evita que una
  VM nueva omita Shielded VM.
- `publicAccessPrevention`: ningún bucket de la entrega es público; la política lo garantiza en toda la
  organización.
- `sql.restrictPublicIp`: Cloud SQL usa solo IP privada; la política evita una instancia expuesta por error.
- `skipDefaultNetworkCreation`: los proyectos usan la VPC compartida; la red `default` sería una red sin
  firewall jerárquico ni registro.
- bigquery en VPC-SC: los logs de auditoría y las métricas se pueden exportar a BigQuery. Restringirlo desde
  ahora evita una salida de datos si alguien crea un dataset. Cuesta nada si no se usa.

## Alternativas descartadas

- **Quitarlas para seguir Fase 3 a la letra**: baja la postura de seguridad sin reducir costo ni complejidad.

## Consecuencias

- Una VM sin Shielded VM, un bucket público, una instancia de Cloud SQL con IP pública o una red `default` fallan
  al crearse. Una excepción requiere cambiar la política en 1-org por pull request.
