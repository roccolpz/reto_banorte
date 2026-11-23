# Runbook: failover de Cloud SQL de prod a us-east4

Cuándo: us-central1 no está disponible y la base de prod no responde, o un simulacro de DR.
Quién: plataforma, con aprobación del responsable del servicio. La promoción es irreversible: la réplica deja de ser
réplica y la primaria anterior queda separada.

Requisito: `enable_dr_replica = true` en `5-workloads/envs/prod` (el default es `false`; ver contrato §8). Sin réplica
DR este runbook no aplica: restaura desde el último backup en otra región.

## 0. Decidir

- ¿La falla es regional (consola de estado de Google Cloud, varias zonas afectadas)? Si es de una zona y `sql_ha = true`,
  Cloud SQL ya hizo failover zonal solo: no sigas.
- Anota la hora de inicio para medir RTO y el último dato confirmado para estimar RPO.

## 1. Identificar instancias

```bash
DATA_PROJECT=<data_project_id de 4-projects/envs/prod>
gcloud sql instances list --project "$DATA_PROJECT" \
  --format 'table(name,region,instanceType,state,masterInstanceName)'
```

La primaria es `CLOUD_SQL_INSTANCE` en us-central1; la réplica es `READ_REPLICA_INSTANCE` en us-east4.

## 2. Revisar el retraso de la réplica

En Cloud Monitoring, métrica `cloudsql.googleapis.com/database/replication/replica_lag` de la réplica.
Ese retraso es la pérdida de datos esperada.

## 3. Promover la réplica

```bash
gcloud sql instances promote-replica <replica> --project "$DATA_PROJECT"
```

Espera `state: RUNNABLE` e `instanceType: CLOUD_SQL_INSTANCE`.

## 4. Mover el tráfico

- Obtén la IP privada nueva: `gcloud sql instances describe <replica> --project "$DATA_PROJECT" --format 'value(ipAddresses[0].ipAddress)'`.
- Actualiza el secreto o la configuración que usan las aplicaciones (registro DNS en `prod.gcp.acme.internal.` o el
  valor en Secret Manager) y reinicia las cargas de us-east4.
- Si las cargas de us-central1 siguen caídas, escala el MIG o el clúster en us-east4.

## 5. Reconciliar Terraform

Terraform todavía describe la topología anterior. Antes del siguiente apply de `5-workloads/envs/prod`:

1. Abre un PR que refleje la nueva primaria (región us-east4) y desactive la réplica hasta reconstruirla.
2. Si el plan propone destruir la instancia promovida, **no lo apliques**: usa `terraform state rm` e `import` para
   apuntar el recurso a la instancia promovida, revisado por dos personas.
3. Pausa el workflow `drift` mientras tanto, o marca el issue como esperado.

## 6. Volver a la normalidad

Cuando us-central1 vuelva, crea una réplica nueva en us-central1 desde la primaria actual y repite este runbook en
sentido inverso en una ventana de mantenimiento.

## 7. Cerrar

- Registra RTO y RPO medidos y compáralos con el objetivo.
- Abre un PR con lo aprendido para este runbook.
