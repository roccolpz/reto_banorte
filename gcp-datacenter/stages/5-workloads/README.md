# Etapa 5-workloads

Despliega las cargas de cada entorno sobre los proyectos de 4-projects. Cada `envs/<env>` llama a `modules/env`; solo
cambia `local.env`.

- Regiones: `primary_region` (us-central1) y `dr_region` (us-east4). Cada una debe tener subred en la salida `subnets`
  de `3-networks/<env>`; dev y qa solo tienen us-central1.
- GKE privado en el proyecto de app (`modules/gke`): zonal en dev/qa, regional en prod (`regional`, null = solo prod),
  nodos con la SA `gke_nodes` y la etiqueta segura `gke-nodes`, secretos cifrados con la llave `gke`, master CIDR del
  contrato §5.
- Clúster GKE DR en `dr_region` (`enable_dr_cluster`, null = solo prod): `<prefix>-<env>-app-gke-dr`, master
  `172.16.31.0/28`, mismos pools y SA. Sin llave `gke-dr`, etcd queda sin CMEK (ADR 0019-i).
- Tamaños por entorno (`gke_node_pools`, `sql_tier`, null = los del entorno): dev/qa `e2-medium` de 1 a 2 nodos y
  `db-custom-1-3840`; prod `e2-standard-2` de 1 a 3 nodos y `db-custom-2-7680`.
- Workload Identity: la KSA `ksa_namespace/ksa_name` actúa como `app_workload`.
- Cloud SQL privado en el proyecto de datos (`modules/cloud-sql`) con la llave `sql`. `sql_ha` y `enable_dr_replica`
  (null = solo prod); la réplica usa `sql-dr` en `dr_region`.
- Bucket CMEK en el proyecto de datos (`modules/storage`). `bucket_dual_region` (null = solo prod) en `true` crea un
  dual-region de las dos regiones con turbo replication y la llave `storage-us` (ADR 0002-d); si no, regional con
  `storage`. `app_workload` recibe `roles/storage.objectUser`.
- MIG con autoscaler en el proyecto de app con la SA `vm` y la etiqueta segura `vm` (`modules/compute-mig`).
  `image_family` (null = Debian 12 público) elige la imagen endurecida (ADR 0018-i).
- Observabilidad en el proyecto de app (`modules/observability`): alertas por correo y un tablero. El proyecto de datos
  entra al metrics scope; el hub y la alerta de túneles VPN solo en prod, para no repetir la alerta por entorno. La
  alerta de retraso de réplica existe donde hay réplica. `uptime_check_host` (null = sin uptime check) vigila el host
  público de la aplicación.
- Cloud Run en el proyecto de app (`modules/cloud-run`), todos los entornos: `<prefix>-<env>-app-run`, escala a cero,
  SA `run`, ingreso solo por el balanceador.
- Balanceador HTTPS global con Cloud Armor OWASP delante de Cloud Run (`modules/load-balancer`, `enable_load_balancer`,
  null = solo prod). Sin `lb_domain`, el certificado administrado usa `<ip>.nip.io` (salidas `lb_ip_address` y
  `lb_domain`).
- Memorystore for Redis `BASIC` 1 GB en el proyecto de datos (`modules/memorystore`, `enable_memorystore`, null = solo
  prod), por el mismo acceso a servicios privados que Cloud SQL.
- Backup and DR (`modules/backup-dr`, `enable_backup_dr`, null = solo prod): bóveda y plan diario de la instancia
  primaria de Cloud SQL con 30 días de retención forzada (ADR 0023).
- `deletion_protection`: null = true solo en prod. En false el bucket también se puede vaciar al destruir.

Lee el estado de `2-security`, `3-networks/hub`, `3-networks/<env>` y `4-projects/<env>`. La llave de las etiquetas
seguras se busca por nombre en el proyecto host (ADR 0019-i). `notification_email` no tiene default: en CI llega como
`TF_VAR_notification_email`.

```sh
cd envs/dev
terraform init -backend-config="bucket=$TF_STATE_BUCKET"
terraform plan
```

Pruebas del módulo compartido: `cd modules/env && terraform init -backend=false && terraform test`.

Salidas (contrato §6): `gke_cluster_name`, `gke_dr_cluster_name` (null en dev y qa), `sql_instance_name`,
`sql_private_ip`, `bucket_name`, `mig_name`.
