# ADR 0007-f: 2-security agrega los proyectos de dev y qa a sus perímetros

- Estado: aceptada
- Fecha: 2026-11-23

## Contexto

Los tres perímetros de VPC-SC (dev, qa, prod) viven en una sola política de acceso de la organización. El IAM de
Access Context Manager se otorga en la política completa: no existe un rol por perímetro. Antes, las SAs
`4-projects-<env>` tenían `roles/accesscontextmanager.policyEditor` en la organización para agregar sus proyectos de
app y datos. Con eso la SA de dev, que se usa desde el environment `dev` de GitHub sin aprobación, podía cambiar o
vaciar el perímetro de prod.

## Decisión

- Solo `4-projects-prod` (environment con aprobación) conserva `policyEditor` y agrega los proyectos de prod.
- Los proyectos de app y datos de dev y qa los agrega `2-security`, que también corre con aprobación. Lee las
  salidas `app_project_number` y `data_project_number` del estado `4-projects/<env>`.
- El estado de `4-projects/<env>` no existe en la primera corrida. 2-security lista el prefijo en el bucket de
  estado antes de leerlo, así que la primera corrida no falla y la siguiente recoge los proyectos.
- El módulo `stages/4-projects/modules/env` recibe `add_to_perimeter` (`true` por default; `false` en dev y qa).
- Las salidas del §6 no cambian.

## Alternativas descartadas

- **Políticas de acceso con alcance (scoped policies) por carpeta de entorno**: dan IAM por entorno, pero cambian
  la política, los perímetros y el formato de `perimeter_names` de 2-security. Es demasiado para esta entrega.
- **Restringir los environments `dev` y `qa` de GitHub a `main`**: cualquier cambio fusionado seguiría alcanzando
  el perímetro de prod con la SA de dev.

## Consecuencias

- Tras crear o recrear los proyectos de dev o qa, hay que volver a correr 2-security para que entren al perímetro.
  Hasta entonces quedan fuera del perímetro, que en la entrega está en dry-run (ADR 0006-e).
- El orden del primer apply cambia: después de `4-projects/envs/dev` y `qa` se corre 2-security otra vez
  (`docs/runbooks/bootstrap-first-apply.md`).
