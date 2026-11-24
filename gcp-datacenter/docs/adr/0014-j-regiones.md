# ADR 0014-j: us-central1 como región principal y us-east4 como región de recuperación

- Estado: aceptada
- Fecha: 2026-11-23

## Contexto

El diseño de Fase 3 fija dos regiones: dev y qa en una, y prod en una principal más una de recuperación (DR) para
las metas RPO ≤ 15 min y RTO ≤ 4 h. Las regiones afectan la política de organización de ubicaciones, el
direccionamiento (§5 del contrato: `10.31.0.0/16` es prod en DR), las VPN del hub y la réplica de Cloud SQL.

## Decisión

- **us-central1 (Iowa)** es la región principal de dev, qa y prod.
- **us-east4 (Virginia del Norte)** es la región de DR de prod: subred `10.31.0.0/16`, Cloud NAT, clúster GKE de
  DR, réplica de Cloud SQL y segundo HA VPN del hub.
- El bucket dual-region usa el par `us-central1`/`us-east4` (ADR 0002-d).
- 1-org restringe las ubicaciones (`gcp.resourceLocations`) a `in:us-central1-locations`,
  `in:us-east4-locations` y la multi-región `us` del bucket y su llave.
- `primary_region` y `dr_region` son variables por entorno en 5-workloads, así que cambiar el par no toca módulos.

Motivos:

- us-central1 tiene el catálogo de servicios más amplio de GCP; todo lo que usa la entrega (GKE, Cloud SQL con
  réplica entre regiones, NCC, HA VPN, VPC-SC) está disponible.
- us-east4 está en otra zona geográfica, así que una falla regional no afecta a las dos. El par sirve para el
  bucket dual-region con turbo replication (ADR 0002-d).
- Las dos están en Estados Unidos, junto a la multi-región `us` que usa el bucket.

## Alternativas descartadas

- **northamerica-south1 (Querétaro)**: menor latencia desde México y datos en el país, pero hay que comprobar que
  ofrezca todos los servicios de la entrega y un par para el bucket dual-region. Es la opción a elegir si el
  cliente exige residencia de datos en México. Esa exigencia no está confirmada: es un supuesto que cambiaría
  esta decisión.
- **us-south1 (Dallas)** como principal: más cerca de Monterrey, pero el diseño de Fase 3 ya se validó con
  us-central1.
- **Una sola región con varias zonas**: no cumple el DR regional que pide la especificación.

## Consecuencias

- La latencia desde México hacia us-central1 se debe medir en las pruebas; esta ADR no la garantiza.
- Mover prod a otra región exige cambiar `primary_region`/`dr_region`, el §5 del contrato y la política de
  ubicaciones de 1-org.
