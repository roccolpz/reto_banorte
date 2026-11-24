# ADR 0010-g: Security Command Center se activa a mano; 1-org configura las notificaciones

- Estado: aceptada
- Fecha: 2026-11-23

## Contexto

Fase 3 pone SCC en `1-org`. Antes, 1-org solo habilitaba la API. Activar SCC en la organización (nivel Standard o
Premium) no tiene recurso de Terraform: se hace en la consola por un administrador de la organización, y el nivel
Premium es una contratación.

## Decisión

- La activación de SCC a nivel organización es un paso manual previo a 1-org, documentado en el runbook del
  primer apply.
- 1-org crea en el proyecto `security`:
  - un tópico de Pub/Sub `<prefix>-scc-findings` con almacenamiento de mensajes en la región principal;
  - una suscripción con retención de 7 días;
  - una configuración de notificación de SCC v2 de la organización (`location = "global"`) que envía los
    hallazgos con `state = "ACTIVE"` a ese tópico.
- 0-bootstrap da a la SA de 1-org `roles/securitycenter.notificationConfigEditor` y a la SA de plan
  `roles/securitycenter.notificationConfigViewer`, y habilita `securitycenter` y `pubsub` en la semilla.
- `security_admins` recibe `securitycenter.adminViewer` y `auditors` recibe `securitycenter.findingsViewer`.

## Alternativas descartadas

- **Activar SCC desde Terraform**: no existe un recurso para la activación de la organización.
- **Exportar hallazgos a BigQuery**: agrega un servicio restringido y costo sin un consumidor definido.

## Consecuencias

- Si SCC no está activo, la creación de la notificación falla en el apply de 1-org.
- Al crear la notificación, SCC da al agente de servicio de la organización permiso de publicar en el tópico. La
  SA de 1-org puede hacerlo porque creó el proyecto `security`.
- Quien consuma los hallazgos (alertas, SIEM) se suscribe al tópico; queda fuera de esta entrega.
