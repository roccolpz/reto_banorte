# ADR 0020-k: grupo qa_approvers de solo lectura para aprobar pases a prod

- Estado: aceptada
- Fecha: 2026-11-24

## Contexto

Un cambio de QA llega a prod solo con la aprobación de dos usuarios de QA con ese privilegio. Hasta ahora
`1-org` no tenía un grupo para ellos: las llaves de `var.groups` eran las de Fase 3 §3.2 y ninguna representaba
a QA. Las SAs por etapa y entorno (0-bootstrap) y los grupos humanos de solo lectura (ADR 0009-g) ya separan
quién despliega de quién revisa; faltaba nombrar a quién aprueba.

Un rol de IAM no puede exigir "dos personas de acuerdo": esa regla vive en GitHub (protección de `main` y
environment `prod`). En GCP, el mínimo privilegio para un aprobador es poder ver lo que aprueba, nada más.

## Decisión

- Nueva llave `qa_approvers` en `var.groups` de `1-org` (correo del grupo de Google, p. ej.
  `gcp-qa-approvers@...`).
- Roles, solo en las carpetas `qa` (lo que validaron) y `prod` (lo que aprueban):
  `roles/browser`, `roles/container.clusterViewer`, `roles/logging.viewer` y `roles/monitoring.viewer`.
- Sin `dev`, sin roles en la organización ni en proyectos sueltos, y sin `roles/viewer`, que abarca todos los
  servicios. Ningún rol de escritura ni de suplantación de SAs (`serviceAccountUser`, `serviceAccountTokenCreator`).
- La prueba de 1-org falla si `qa_approvers` recibe un rol fuera de `qa`/`prod` o un rol que no sea de lectura.

## Alternativas descartadas

- **Reusar `devops` o `developers`**: tienen `roles/viewer` en los tres entornos y otras personas; no distingue
  a quién tiene el privilegio de aprobar.
- **Cuenta de servicio y roles de escritura propios (módulo `env-access` en `test-orchestration`)**: duplicaba las
  SAs por etapa de 0-bootstrap y modificaba el legado congelado. Se revirtió.

## Consecuencias

- El grupo se crea a mano en Cloud Identity y su correo va en `groups.qa_approvers`.
- Falta la parte de GitHub (siguiente paso): equipo `qa-approvers` en CODEOWNERS de las raíces de prod y un
  ruleset en `main` con dos aprobaciones obligatorias. El environment `prod` de GitHub pide una sola aprobación
  de su lista de reviewers, así que por sí solo no cumple la regla de dos.
