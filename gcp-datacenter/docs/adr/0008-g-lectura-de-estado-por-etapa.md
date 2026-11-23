# ADR 0008-g: cada etapa lee solo los estados que consume; la SA de plan lee todo

- Estado: aceptada
- Fecha: 2026-11-23

## Contexto

Fase 3 pide que solo la cuenta de servicio de cada etapa lea y escriba su prefijo del bucket de estado. Antes,
`0-bootstrap` daba `roles/storage.objectViewer` sin condición sobre todo el bucket a todas las SAs: la SA de
`5-workloads-dev` podía leer el estado de prod, que incluye salidas sensibles.

Las etapas no pueden quedar aisladas del todo: cada una lee las salidas de las anteriores con
`terraform_remote_state`. Y la SA de plan corre `terraform plan` de todas las etapas, en PRs y en la detección de
drift, así que necesita leer todos los prefijos.

## Decisión

- `local.state_read_prefixes` en `0-bootstrap` lista, por SA de etapa, los prefijos que lee. La lista sale de los
  `terraform_remote_state` del código (por ejemplo, `5-workloads-dev` lee `2-security`, `3-networks/hub`,
  `3-networks/dev` y `4-projects/dev`).
- El `objectViewer` de cada SA de etapa lleva una condición IAM: puede listar el bucket
  (`resource.type == "storage.googleapis.com/Bucket"`, lo usa el backend gcs y el listado de 2-security) y leer
  objetos solo bajo esos prefijos (`resource.name.startsWith(...)`).
- La escritura no cambia: cada SA escribe solo bajo su propio prefijo.
- Excepción: la SA de plan conserva lectura de todo el bucket y ningún permiso de escritura. Solo se impersona
  desde el repositorio autorizado y no puede cambiar recursos.

## Alternativas descartadas

- **Un bucket por etapa o por entorno**: aísla mejor, pero cambia el backend de todas las etapas y el formato de
  `state_bucket` del contrato.
- **Una SA de plan por entorno**: cierra la lectura cruzada de la SA de plan, pero multiplica las SAs, los
  bindings de WIF y los jobs del pipeline. Queda como mejora si se exige aislamiento total.
- **Mantener la lectura completa**: incumple Fase 3 sin necesidad.

## Consecuencias

- Una etapa que empiece a leer un estado nuevo necesita su prefijo en `local.state_read_prefixes` y una corrida
  de 0-bootstrap antes de su primer plan; si falta, el plan falla con 403 al leer el estado.
- Listar el bucket muestra los nombres de los objetos de todos los prefijos, pero no su contenido.
