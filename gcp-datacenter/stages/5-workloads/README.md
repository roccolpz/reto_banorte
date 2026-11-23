# Etapa 5-workloads

Despliega las cargas de cada entorno sobre los proyectos de 4-projects. Cada `envs/<env>` llama a `modules/env`; solo
cambia `local.env`.

- GKE privado en el proyecto de app (`modules/gke`): zonal en dev/qa, regional en prod (`regional`, null = solo prod),
  nodos con la SA `gke_nodes`, secretos cifrados con la llave `gke`, master CIDR del contrato §5.
- Workload Identity: la KSA `ksa_namespace/ksa_name` actúa como `app_workload`.
- Cloud SQL privado en el proyecto de datos (`modules/cloud-sql`) con la llave `sql`. `sql_ha` y `enable_dr_replica`
  en false por default; la réplica usa `sql-dr` en us-east4.
- Bucket CMEK en el proyecto de datos (`modules/storage`). `bucket_dual_region = true` crea un dual-region
  US-CENTRAL1 + US-EAST4 con turbo replication y la llave `storage-us` (ADR 0002-d); si no, regional con `storage`.
  `app_workload` recibe `roles/storage.objectUser`.
- MIG e2-micro en el proyecto de app con la SA `vm` (`modules/compute-mig`). El firewall de la VPC debe permitir los
  rangos de health check de Google.
- Alertas por correo en el proyecto de app; datos y hub entran a su metrics scope (`modules/observability`).
- `deletion_protection`: null = true solo en prod. En false el bucket también se puede vaciar al destruir.

Lee el estado de `2-security`, `3-networks/hub`, `3-networks/<env>` y `4-projects/<env>`. `notification_email` no
tiene default: en CI llega como `TF_VAR_notification_email`.

```sh
cd envs/dev
terraform init -backend-config="bucket=$TF_STATE_BUCKET"
terraform plan
```

Pruebas del módulo compartido: `cd modules/env && terraform init -backend=false && terraform test`.

Salidas (contrato §6): `gke_cluster_name`, `sql_instance_name`, `sql_private_ip`, `bucket_name`, `mig_name`.
