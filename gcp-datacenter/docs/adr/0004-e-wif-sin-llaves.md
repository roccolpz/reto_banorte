# ADR 0004-e: Workload Identity Federation en lugar de llaves de cuenta de servicio

- Estado: aceptada
- Fecha: 2026-11-23

## Contexto

GitHub Actions necesita credenciales de GCP para planear y aplicar. La forma clásica es guardar una llave JSON de una
cuenta de servicio como secreto del repositorio. Esa llave no expira, se puede copiar fuera de GitHub y, si se filtra,
da acceso hasta que alguien la revoque a mano. La especificación prohíbe llaves de SA.

## Decisión

- `0-bootstrap` crea un pool y un proveedor de Workload Identity Federation que confía en el emisor OIDC de GitHub.
- La condición del proveedor acepta solo el repositorio `roccolpz/reto_banorte`.
- Cada etapa y entorno tiene su propia SA (salida `stage_service_accounts`), y una SA `plan` de solo lectura para los
  pull requests y la detección de drift.
- Las SA `*-prod` y las de `1-org`, `2-security` y `3-networks-hub` solo se pueden impersonar con un token cuyo
  `environment` sea `prod` y cuyo `ref` sea `refs/heads/main` (`attribute.prod_main`, agregado en ADR 0021-k): las
  etapas comunes cambian recursos de los que depende prod. Esos jobs corren en el environment `prod` de GitHub, que
  pide una aprobación; las dos aprobaciones de QA las exige el job `qa-approval` (ADR 0021-k). La SA `plan` se impersona desde cualquier job del repositorio.
- Los workflows usan `google-github-actions/auth` con `workload_identity_provider` y `service_account` tomados de
  variables de GitHub (no secretos: no son credenciales). Los workflows piden `id-token: write` solo en los jobs que
  se autentican.
- La política `sa_keys.rego` rechaza cualquier `google_service_account_key` en un plan.

## Alternativas descartadas

- **Llave JSON como secreto de GitHub**: credencial de larga vida, prohibida por la especificación.
- **Una sola SA para todo el pipeline**: un PR de dev podría tocar prod; se pierde el aislamiento por etapa.
- **Runners propios en GCP con la SA del nodo**: más infraestructura que mantener y la misma identidad para todo.

## Consecuencias

- No hay ningún secreto de GCP en GitHub. Un token robado dura minutos y solo sirve desde este repositorio.
- Las variables de GitHub con los correos de las SA se llenan una vez, después del primer apply de `0-bootstrap`.
- Los forks no obtienen credenciales: los PR desde forks no pueden planear contra GCP.
- La SA `plan` necesita lectura sobre todos los prefijos del estado y permisos de lectura amplios en la organización.
