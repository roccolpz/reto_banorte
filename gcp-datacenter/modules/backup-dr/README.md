# Módulo `backup-dr`

Backup and DR Service: una bóveda de respaldos con retención mínima forzada (30 días por defecto), un plan de respaldo
diario para Cloud SQL con la misma retención y la asociación de cada instancia indicada al plan. La cuenta de servicio
de la bóveda recibe `roles/backupdr.cloudSqlOperator` en el proyecto.

Estos respaldos se suman a los respaldos automáticos y PITR de Cloud SQL (módulo `cloud-sql`) y a la réplica en
`us-east4`: quedan en una bóveda aislada que ni un administrador del proyecto puede borrar antes de la retención.

Bóveda, plan e instancias deben estar en la misma región. Mientras la bóveda tenga respaldos dentro de la retención no se
puede borrar: un `destroy` de prod falla hasta que venzan (ver [destroy-dev](../../docs/runbooks/destroy-dev.md)).

## Uso

```hcl
module "backup_dr" {
  source        = "../../modules/backup-dr"
  name          = "acme-prod-data"
  project_id    = "acme-prod-data-xxxx"
  sql_instances = { primary = module.sql.instance_name }
  labels        = { env = "prod", app = "landing-zone", owner = "plataforma", cost_center = "TI-001", managed_by = "terraform" }
}
```

Ejemplo completo en [examples/basic](examples/basic/main.tf).

## Entradas

| Nombre | Descripción | Tipo | Default | Requerido |
|---|---|---|---|:-:|
| name | Prefijo de bóveda y plan. | `string` | n/a | sí |
| project_id | Proyecto de la bóveda y de las instancias. | `string` | n/a | sí |
| region | Región (la de las instancias). | `string` | `"us-central1"` | no |
| sql_instances | Llave → nombre de instancia de Cloud SQL. | `map(string)` | `{}` | no |
| retention_days | Retención en días (1 a 90). | `number` | `30` | no |
| backup_window_start_hour | Inicio de la ventana diaria de 4 horas. | `number` | `2` | no |
| time_zone | Zona horaria de la ventana. | `string` | `"America/Mexico_City"` | no |
| labels | Etiquetas obligatorias. | `map(string)` | n/a | sí |

## Salidas

| Nombre | Descripción |
|---|---|
| vault_id | ID de la bóveda. |
| backup_plan_id | ID del plan de Cloud SQL. |

## Pruebas

```sh
terraform init -backend=false && terraform test
```
