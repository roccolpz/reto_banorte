# Runbook: responder a un issue de drift

El workflow `drift` corre cada día a las 12:00 UTC. Cuando el plan de una raíz tiene diferencias abre o actualiza el
issue `Drift: <raíz>` con la etiqueta `drift`, y lo cierra solo cuando el drift desaparece.

## 1. Entender el cambio

Abre el plan del issue. Para cada recurso con cambios, busca quién lo hizo en los registros de auditoría:

```bash
gcloud logging read \
  'protoPayload.resourceName:"<nombre-del-recurso>" AND logName:"cloudaudit.googleapis.com%2Factivity"' \
  --project <proyecto> --freshness 2d --format 'table(timestamp,protoPayload.authenticationInfo.principalEmail,protoPayload.methodName)'
```

## 2. Decidir

| Situación | Acción |
|-----------|--------|
| Cambio manual no autorizado | Revertirlo: ejecuta `apply` con Run workflow (aplica todas las raíces). Avisa a seguridad si fue un humano sin permiso. |
| Cambio manual que se quiere conservar | Abre un PR que lo lleve al código; el plan del PR debe quedar sin cambios para ese recurso. |
| Cambio hecho por GCP (valores por defecto nuevos, campos calculados) | PR con el valor explícito o con `lifecycle.ignore_changes` justificado en un comentario. |
| Recurso borrado fuera de Terraform | El apply lo vuelve a crear. Si no debe existir, PR que lo quite del código. |
| Drift causado por un incidente o un failover de DR | Esperado: deja un comentario en el issue y reconcilia con el runbook del incidente. |

## 3. Cerrar

El siguiente run de `drift` cierra el issue si ya no hay diferencias. Si lo cierras a mano antes, el próximo run lo
vuelve a abrir mientras el drift exista.
