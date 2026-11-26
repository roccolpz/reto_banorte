# ADR 0003-e: Etapas con un estado GCS por etapa y entorno

- Estado: aceptada
- Fecha: 2026-11-23

## Contexto

El repositorio empezó con una sola raíz (`stages/test-orchestration`) con estado local. Un estado único para toda la
organización obliga a que cada cambio, por pequeño que sea, planee todo, y a que una sola identidad tenga permisos
sobre todo. Un error en una red de dev puede bloquear un cambio de prod. El estado local no se comparte ni se bloquea.

## Decisión

- La infraestructura se divide en seis etapas ordenadas: `0-bootstrap`, `1-org`, `2-security`, `3-networks`,
  `4-projects`, `5-workloads`. Las etapas 3 a 5 tienen una raíz por entorno (`envs/dev`, `envs/qa`, `envs/prod`);
  `3-networks` tiene además la raíz `hub`.
- Cada raíz tiene su propio estado en un único bucket GCS con CMEK, creado por `0-bootstrap`, con prefijo
  `<etapa>[/<entorno>]` (`gcp-datacenter/docs/CONTRATO.md` §3). El bucket se pasa en `terraform init -backend-config`.
- Una etapa lee las salidas de las anteriores con `terraform_remote_state`. Las salidas son la interfaz entre
  etapas y sus nombres están fijados en el contrato (§6).
- Cada raíz se aplica con su propia cuenta de servicio (ADR 0004-e).
- CI descubre las raíces buscando `versions.tf` bajo `stages/` (`scripts/discover-roots.sh`), sin lista fija.

## Alternativas descartadas

- **Un estado único**: radio de impacto total y planes lentos.
- **Terraform workspaces por entorno**: los entornos comparten código y backend, pero no permiten permisos distintos por
  entorno ni diferencias de topología (prod tiene dos regiones).
- **Terragrunt**: añade una herramienta más al pipeline y al equipo; el patrón de raíces simples cubre la necesidad.

## Consecuencias

- Un cambio de prod no planea dev, y la SA de dev no puede tocar prod.
- El orden de apply importa: `apply.yml` encadena 1 → 2 → 3-hub y luego, por entorno, 3 → 4 → 5.
- Cambiar el nombre de una salida rompe a sus consumidores: se trata como cambio de interfaz y se actualiza el contrato.
- `0-bootstrap` se aplica primero con estado local y luego migra su estado al bucket que crea
  (runbook `bootstrap-first-apply.md`).
- `stages/test-orchestration` queda como legado con estado local y fuera del pipeline de apply. Se borró el
  2026-11-25, después de confirmar que sus recursos ya no existían en GCP.
