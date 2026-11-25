locals {
  # Sin valor explícito, prod usa HA, réplica DR, bucket dual-region y clúster DR: el pipeline no pasa tfvars.
  sql_ha             = coalesce(var.sql_ha, var.env == "prod")
  enable_dr_replica  = coalesce(var.enable_dr_replica, var.env == "prod")
  bucket_dual_region = coalesce(var.bucket_dual_region, var.env == "prod")
  enable_dr_cluster  = coalesce(var.enable_dr_cluster, var.env == "prod")
  # Balanceador con Cloud Armor, Memorystore y Backup and DR: solo prod por costo (ADR 0023).
  # Cloud Run necesita la SA run de 4-projects: hasta que 4-projects se aplique, el plan de 5-workloads no la crea.
  enable_cloud_run     = contains(keys(var.service_accounts), "run")
  enable_load_balancer = local.enable_cloud_run && coalesce(var.enable_load_balancer, var.env == "prod")
  enable_memorystore   = coalesce(var.enable_memorystore, var.env == "prod")
  enable_backup_dr     = coalesce(var.enable_backup_dr, var.env == "prod")
  name_app             = "${var.prefix}-${var.env}-app"
  database_version     = "POSTGRES_18"
  name_data            = "${var.prefix}-${var.env}-data"
  subnet               = var.subnets[var.primary_region]

  # Tamaños por entorno (R12); gke_node_pools y sql_tier explícitos los reemplazan.
  sizing = {
    dev  = { machine_type = "e2-medium", max_count = 2, sql_tier = "db-custom-1-3840" }
    qa   = { machine_type = "e2-medium", max_count = 2, sql_tier = "db-custom-1-3840" }
    prod = { machine_type = "e2-standard-2", max_count = 3, sql_tier = "db-custom-2-7680" }
  }
  gke_node_pools = var.gke_node_pools != null ? var.gke_node_pools : {
    default = { machine_type = local.sizing[var.env].machine_type, min_count = 1, max_count = local.sizing[var.env].max_count }
  }
  sql_tier = coalesce(var.sql_tier, local.sizing[var.env].sql_tier)

  # Contrato §5.
  master_cidrs = {
    dev  = "172.16.10.0/28"
    qa   = "172.16.20.0/28"
    prod = "172.16.30.0/28"
  }
  dr_master_cidr = "172.16.31.0/28"

  # Etiquetas seguras de firewall: una sola llave por VPC, un valor por tipo de carga.
  gke_tags = { (var.secure_tag_key) = var.secure_tag_values["gke-nodes"] }
  vm_tags  = { (var.secure_tag_key) = var.secure_tag_values["vm"] }

  # Solo prod vigila los túneles VPN del hub: una alerta por túnel y no una por entorno (P13).
  # Sin el propio proyecto de app: con compact_projects (1-org) app y datos son el mismo proyecto.
  monitored_project_ids = [for p in concat([var.data_project_id], var.env == "prod" ? [var.hub_project_id] : []) : p if p != var.app_project_id]
}

# --- GKE privado en el proyecto de app ---

module "gke" {
  source = "../../../../modules/gke"

  cluster_name               = "${local.name_app}-gke"
  project_id                 = var.app_project_id
  region                     = var.primary_region
  regional                   = var.regional
  network                    = var.network_self_link
  subnetwork                 = local.subnet.self_link
  pods_range_name            = local.subnet.pods_range_name
  services_range_name        = local.subnet.services_range_name
  master_ipv4_cidr_block     = local.master_cidrs[var.env]
  master_authorized_networks = var.master_authorized_networks
  node_service_account       = var.service_accounts["gke_nodes"]
  node_pools                 = local.gke_node_pools
  resource_manager_tags      = local.gke_tags
  database_encryption_key    = var.kms_keys["gke"]
  deletion_protection        = var.deletion_protection
  labels                     = var.labels
}

# Clúster en espera en la región DR (R11). Sin llave gke-dr en esa región, etcd queda sin CMEK (ADR 0019-i).
module "gke_dr" {
  source = "../../../../modules/gke"
  count  = local.enable_dr_cluster ? 1 : 0

  cluster_name               = "${local.name_app}-gke-dr"
  project_id                 = var.app_project_id
  region                     = var.dr_region
  regional                   = var.regional
  network                    = var.network_self_link
  subnetwork                 = var.subnets[var.dr_region].self_link
  pods_range_name            = var.subnets[var.dr_region].pods_range_name
  services_range_name        = var.subnets[var.dr_region].services_range_name
  master_ipv4_cidr_block     = local.dr_master_cidr
  master_authorized_networks = var.master_authorized_networks
  node_service_account       = var.service_accounts["gke_nodes"]
  node_pools                 = local.gke_node_pools
  resource_manager_tags      = local.gke_tags
  database_encryption_key    = lookup(var.kms_keys, "gke-dr", null)
  deletion_protection        = var.deletion_protection
  labels                     = var.labels
}

resource "google_service_account_iam_member" "workload_identity" {
  service_account_id = "projects/${var.app_project_id}/serviceAccounts/${var.service_accounts["app_workload"]}"
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.app_project_id}.svc.id.goog[${var.ksa_namespace}/${var.ksa_name}]"

  # El pool <proyecto>.svc.id.goog existe solo después del primer clúster con Workload Identity.
  depends_on = [module.gke]
}

# --- Cloud SQL privado en el proyecto de datos ---

# Cloud SQL no reutiliza un nombre hasta una semana después de borrarlo: el sufijo aleatorio permite recrear dev.
# Cambiar la versión mayor crea instancias nuevas con otro nombre, en vez de un upgrade en sitio (no lo admite
# con réplica entre regiones sin pasos manuales).
resource "random_id" "sql" {
  byte_length = 2
  keepers     = { database_version = local.database_version }
}

module "sql" {
  source = "../../../../modules/cloud-sql"

  name                = "${local.name_data}-sql-${random_id.sql.hex}"
  project_id          = var.data_project_id
  region              = var.primary_region
  network             = var.network_self_link
  tier                = local.sql_tier
  database_version    = local.database_version
  kms_key_name        = var.kms_keys["sql"]
  ha                  = local.sql_ha
  enable_dr_replica   = local.enable_dr_replica
  dr_region           = var.dr_region
  dr_kms_key_name     = lookup(var.kms_keys, "sql-dr", null)
  deletion_protection = var.deletion_protection
  labels              = var.labels
}

# --- Bucket CMEK en el proyecto de datos ---

module "storage" {
  source = "../../../../modules/storage"

  name              = "${var.data_project_id}-app"
  project_id        = var.data_project_id
  location          = local.bucket_dual_region ? "US" : upper(var.primary_region)
  dual_region       = local.bucket_dual_region ? [upper(var.primary_region), upper(var.dr_region)] : []
  turbo_replication = local.bucket_dual_region
  kms_key_name      = local.bucket_dual_region ? var.kms_keys["storage-us"] : var.kms_keys["storage"]
  force_destroy     = !var.deletion_protection
  labels            = var.labels
}

resource "google_storage_bucket_iam_member" "app_workload" {
  bucket = module.storage.bucket_name
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${var.service_accounts["app_workload"]}"
}

# --- MIG con autoscaler en el proyecto de app ---

module "mig" {
  source = "../../../../modules/compute-mig"

  name                  = local.name_app
  project_id            = var.app_project_id
  region                = var.primary_region
  subnetwork            = local.subnet.self_link
  service_account_email = var.service_accounts["vm"]
  image_family          = var.image_family
  resource_manager_tags = local.vm_tags
  labels                = var.labels
}

# --- Observabilidad: alertas y tablero en app; datos (y el hub en prod) en su metrics scope ---

module "observability" {
  source = "../../../../modules/observability"

  project_id               = var.app_project_id
  name_prefix              = "${var.prefix}-${var.env}"
  notification_email       = var.notification_email
  monitored_project_ids    = local.monitored_project_ids
  enable_vpn_alert         = var.env == "prod"
  enable_replica_lag_alert = local.enable_dr_replica
  uptime_check_host        = var.uptime_check_host
  labels                   = var.labels
}

# --- Cloud Run detrás del balanceador (escala a cero) ---

module "cloud_run" {
  source = "../../../../modules/cloud-run"
  count  = local.enable_cloud_run ? 1 : 0

  name                  = "${local.name_app}-run"
  project_id            = var.app_project_id
  region                = var.primary_region
  service_account_email = var.service_accounts["run"]
  deletion_protection   = var.deletion_protection
  labels                = var.labels
}

# --- Balanceador HTTPS global con Cloud Armor (OWASP) ---

module "load_balancer" {
  source = "../../../../modules/load-balancer"
  count  = local.enable_load_balancer ? 1 : 0

  name              = "${local.name_app}-lb"
  project_id        = var.app_project_id
  region            = module.cloud_run[0].region
  cloud_run_service = module.cloud_run[0].service_name
  domain            = var.lb_domain
  labels            = var.labels
}

# --- Memorystore for Redis en el proyecto de datos ---

module "memorystore" {
  source = "../../../../modules/memorystore"
  count  = local.enable_memorystore ? 1 : 0

  name       = "${local.name_data}-redis"
  project_id = var.data_project_id
  region     = var.primary_region
  network    = replace(var.network_self_link, "https://www.googleapis.com/compute/v1/", "")
  labels     = var.labels
}

# --- Backup and DR: respaldo diario de Cloud SQL con 30 días de retención ---

module "backup_dr" {
  source = "../../../../modules/backup-dr"
  count  = local.enable_backup_dr ? 1 : 0

  name          = local.name_data
  project_id    = var.data_project_id
  region        = var.primary_region
  sql_instances = { primary = module.sql.instance_name }
  labels        = var.labels
}
