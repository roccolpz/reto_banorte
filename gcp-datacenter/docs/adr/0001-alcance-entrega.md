# ADR 0001: Alcance de la entrega del 3 de diciembre de 2026

- Estado: aceptada
- Fecha: 2026-11-23

## Contexto

Al 23 de noviembre el repositorio cubría alrededor del 10 % de la especificación: cuatro módulos parciales y una raíz
monolítica de prueba con estado local. Quedan nueve días hábiles. La especificación completa (etapas 0 a 5, DR probado,
SCC sin hallazgos) no cabe en ese tiempo.

## Decisión

Se entrega el código completo de las etapas 0 a 5 con este alcance:

- Incluido: bootstrap (bucket de estado con CMEK, WIF, una SA por etapa), organización (carpetas, org policies,
  firewall jerárquico, sink de auditoría), seguridad (KMS con rotación de 90 días, Secret Manager, VPC-SC por entorno),
  redes (hub, spokes por entorno con Shared VPC, NCC, HA VPN con BGP hacia una VPC que simula on-premises, Cloud NAT,
  DNS privado con reenvío), proyectos de servicio, cargas (GKE, MIG, Cloud SQL con IP privada, Cloud Storage),
  observabilidad básica, pipeline de GitHub Actions con políticas como código, pruebas `terraform test` por módulo,
  documentación (README, ADR, runbooks).
- Fuera de esta entrega (documentado como siguiente fase): balanceador HTTPS global y Cloud Armor, Cloud Run,
  Memorystore, Filestore, Backup and DR Service, Infracost, simulacro de DR medido, Cloud Interconnect.

On-premises se simula con una VPC `onprem-sim` en GCP conectada por HA VPN, porque el equipo no tiene un sitio físico.

## Consecuencias

- Se pueden demostrar seis de los ocho criterios de aceptación: despliegue desde cero, segundo plan sin cambios,
  destroy de dev, PR bloqueado por política, conectividad privada y DNS hacia on-premises, y módulos con README,
  ejemplo y prueba.
- No se demuestran: SCC sin hallazgos críticos o altos, y el simulacro de DR dentro del RTO. (Actualización 2026-11-25: ambos se demostraron, ver `docs/registro/scc-2026-11-24.md` y `docs/registro/simulacro-dr-2026-11-25.md`.)
- El código se valida con `terraform validate` y `terraform test` con proveedores simulados. El despliegue real en GCP
  lo ejecuta quien tenga acceso a la organización.

## Actualización (2026-11-24)

ADR 0023 agrega el balanceador HTTPS con Cloud Armor, Cloud Run, Memorystore, Backup and DR, Infracost y el presupuesto
con alertas. Filestore, Cloud IDS y Cloud Interconnect quedan como desviaciones documentadas en ese ADR. Los módulos se
versionan con tags (ADR 0024). La llave de rotación de KMS tiene su runbook (`rotacion-llaves-kms.md`).
