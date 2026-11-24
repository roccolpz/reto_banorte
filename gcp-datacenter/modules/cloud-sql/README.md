# Módulo `cloud-sql`

Instancia Cloud SQL para PostgreSQL solo con IP privada (sin IP pública), SSL obligatorio (`ENCRYPTED_ONLY`),
CMEK, autenticación IAM (`cloudsql.iam_authentication=on`), respaldos diarios y PITR. Con `ha = true` la primaria es
`REGIONAL`; con `enable_dr_replica = true` crea una réplica de lectura en `dr_region` (us-east4) cifrada con su propia
llave.

Requisitos previos: Private Service Access en la VPC del host (lo hace `3-networks`), proyecto adjunto a la Shared VPC
y permiso de cifrado del agente de Cloud SQL (`service-<num>@gcp-sa-cloud-sql.iam.gserviceaccount.com`) sobre ambas
llaves (lo hace `4-projects`). No crea usuarios ni contraseñas: los usuarios IAM se agregan aparte.

## Uso

```hcl
module "cloud_sql" {
  source            = "../../modules/cloud-sql"
  name              = "acme-prod-data-pg"
  project_id        = "acme-prod-data-xxxx"
  network           = "projects/acme-prod-net-host-xxxx/global/networks/acme-prod-net-vpc"
  kms_key_name      = "projects/.../locations/us-central1/keyRings/.../cryptoKeys/sql"
  ha                = true
  enable_dr_replica = true
  dr_kms_key_name   = "projects/.../locations/us-east4/keyRings/.../cryptoKeys/sql-dr"
  labels            = { env = "prod", app = "landing-zone", owner = "plataforma", cost_center = "TI-001", managed_by = "terraform" }
}
```

Ejemplo completo en [examples/basic](examples/basic/main.tf).

## Entradas

| Nombre | Descripción | Tipo | Default | Requerido |
|---|---|---|---|:-:|
| name | Nombre de la primaria; la réplica es `<name>-dr`. | `string` | n/a | sí |
| project_id | Proyecto de datos. | `string` | n/a | sí |
| region | Región de la primaria. | `string` | `"us-central1"` | no |
| network | VPC del host con PSA. | `string` | n/a | sí |
| database_version | Versión `POSTGRES_*`. | `string` | `"POSTGRES_16"` | no |
| tier | Tipo de máquina. | `string` | `"db-custom-1-3840"` | no |
| disk_size_gb | Disco inicial (autoresize). | `number` | `10` | no |
| kms_key_name | Llave KMS de la primaria. | `string` | n/a | sí |
| ha | Alta disponibilidad regional. | `bool` | `false` | no |
| enable_dr_replica | Crea la réplica DR. | `bool` | `false` | no |
| dr_region | Región de la réplica. | `string` | `"us-east4"` | no |
| dr_kms_key_name | Llave KMS en la región DR (obligatoria con réplica). | `string` | `null` | no |
| backup_start_time | Hora UTC del respaldo. | `string` | `"03:00"` | no |
| retained_backups | Respaldos que se conservan. | `number` | `7` | no |
| transaction_log_retention_days | Días de logs para PITR (1-7). | `number` | `7` | no |
| deletion_protection | Protección contra borrado. | `bool` | `false` | no |
| labels | Etiquetas obligatorias. | `map(string)` | n/a | sí |

## Salidas

| Nombre | Descripción |
|---|---|
| instance_name | Nombre de la primaria. |
| connection_name | Nombre de conexión para el Auth Proxy. |
| private_ip_address | IP privada de la primaria. |
| replica_name | Nombre de la réplica DR o `null`. |

## Pruebas

```sh
terraform init -backend=false && terraform test
```
