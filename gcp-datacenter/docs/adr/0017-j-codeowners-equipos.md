# ADR 0017-j: CODEOWNERS con equipos de una organización de GitHub

- Estado: aceptada
- Fecha: 2026-11-23

## Contexto

La especificación pide "CODEOWNERS por etapa (red, seguridad, plataforma)". Fase 3 (sección 3.2) asigna la
revisión a grupos: `gcp-security-admins` revisa las etapas 1 y 2, `gcp-network-admins` la 3, `gcp-devops` la 4 y
la 5, y `gcp-org-admins` administra. El repositorio de trabajo vive en una cuenta personal de GitHub, donde no
existen equipos.

## Decisión

- `.github/CODEOWNERS` asigna cada etapa y módulo a un equipo de GitHub con el mismo nombre que su grupo de
  Google, bajo la organización `acme`.
- El repositorio de la entrega debe vivir en una organización de GitHub con los equipos `gcp-org-admins`,
  `gcp-security-admins`, `gcp-network-admins` y `gcp-devops`, con acceso de escritura al repositorio. Si la
  organización no se llama `acme`, se reemplaza el prefijo en CODEOWNERS.
- La protección de main activa "Require review from Code Owners".

## Alternativas descartadas

- **Usuarios individuales**: el archivo quedaría atado a personas y habría que editarlo en cada cambio de equipo.
- **Dejarlo comentado como plantilla**: no tiene efecto, que es el hallazgo R3.

## Consecuencias

- Mientras el repositorio siga en la cuenta personal, GitHub marca los equipos como desconocidos y CODEOWNERS no
  pide revisiones.
- Un cambio de pertenencia a los grupos de Google no cambia los equipos de GitHub: hay que mantener los dos, o
  sincronizarlos con Team Sync si la organización usa SSO.
