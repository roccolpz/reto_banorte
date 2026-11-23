# ADR 0009-g: los grupos humanos solo leen; break_glass para emergencias

- Estado: aceptada
- Fecha: 2026-11-23

## Contexto

Fase 3 pide que los cambios lleguen por pull request y los aplique el pipeline con las SAs de cada etapa. Antes,
`1-org` daba roles de escritura a los grupos humanos: `org_admins` tenía `organizationAdmin` y otros grupos
podían editar proyectos de los entornos. Con eso una persona podía saltarse la revisión y el plan.

Una organización sin ningún humano con permisos de administración no se puede recuperar si el pipeline o WIF
fallan.

## Decisión

- Los grupos ordinarios (`org_admins`, `billing_admins`, `security_admins`, `network_admins`, `devops`,
  `developers`, `auditors`) solo reciben roles de lectura: visores de organización, carpetas, org policies, red,
  KMS, Access Context Manager y hallazgos de SCC, más `roles/viewer` en las carpetas de entorno para `devops` y
  `developers`.
- Un grupo nuevo, `break_glass`, tiene `organizationAdmin`, `folderAdmin` y `orgpolicy.policyAdmin`. Fuera de un
  incidente queda sin miembros. Cada alta se hace a mano en Cloud Identity y queda en los logs de auditoría de
  administración.
- La prueba de 1-org falla si un grupo distinto de `break_glass` recibe un rol de escritura.

## Alternativas descartadas

- **Mantener `organizationAdmin` en `org_admins`**: deja un camino permanente que evita el pipeline.
- **Acceso temporal con Privileged Access Manager**: es la opción más fina, pero agrega un servicio y sus
  permisos fuera del alcance de esta entrega (ADR 0001). Puede sustituir a `break_glass` más adelante.

## Consecuencias

- El runbook de operación debe describir el procedimiento: quién aprueba el alta en `break_glass`, cuánto dura y
  cómo se revierte.
- Los cambios urgentes sin incidente declarado siguen pasando por pull request.
