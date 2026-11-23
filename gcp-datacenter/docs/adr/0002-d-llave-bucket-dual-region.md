# ADR 0002-d: Llave KMS para el bucket dual-region de prod

- Estado: aceptada (2-security publica `storage-us`; 1-org permite `us` y `US`)
- Fecha: 2026-11-23

## Contexto

El contrato (§6) define `kms_keys[env][purpose]` con llaves en us-central1 (y `sql-dr` en us-east4 para prod). La
etapa 5-workloads de prod crea un bucket dual-region configurable (`US-CENTRAL1` + `US-EAST4`, ubicación `US`) con
turbo replication.

Cloud Storage exige que la llave CMEK esté en la misma ubicación que el bucket. Para un dual-region configurable, la
documentación de Cloud Storage dice que la ubicación del keyring debe coincidir con el código de ubicación del
dual-region, es decir `us`. Una llave en `us-central1` no sirve: el apply fallaría.

## Decisión

- 2-security agrega en prod una llave con `purpose = "storage-us"` en la ubicación multi-región `us`, con la misma
  rotación de 90 días. Queda en `kms_keys["prod"]["storage-us"]`. No cambia ningún nombre existente del §6.
- 4-projects concede el permiso de cifrado al agente de Cloud Storage del proyecto de datos sobre toda llave cuyo
  `purpose` empiece por `storage`, así que no requiere cambios cuando la llave aparezca.
- 5-workloads usa `storage-us` cuando el bucket es dual-region y `storage` cuando es regional. Si la llave no existe,
  el plan de prod falla con un error de llave inexistente, en lugar de fallar más tarde en el apply.

## Consecuencias

- Hasta que 2-security publique `storage-us`, el plan de 5-workloads/prod falla, o se usa `bucket_dual_region = false`
  en prod (bucket regional en us-central1, sin turbo replication).
- dev y qa no se ven afectados: sus buckets son regionales.
- Política de organización: 1-org restringe `gcp.resourceLocations` a `in:us-central1-locations` e
  `in:us-east4-locations`, grupos que no incluyen multi-regiones. La guía de ubicaciones de Cloud Storage dice que, en
  un dual-region configurable, el código de ubicación (`US`) es el que evalúa la restricción de ubicaciones y también
  la ubicación de la llave CMEK. 1-org debe permitir además el valor `us` (y `US`, porque la guía de ubicaciones de
  Resource Manager distingue mayúsculas según el servicio), sin abrir todo `in:us-locations`. El mismo valor cubre el
  keyring `us` de la llave `storage-us`.
