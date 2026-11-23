locals {
  name_app  = "${var.prefix}-${var.env}-app"
  name_data = "${var.prefix}-${var.env}-data"
  region    = "us-central1"

  # Contrato §5.
  master_cidrs = {
    dev  = "172.16.10.0/28"
    qa   = "172.16.20.0/28"
    prod = "172.16.30.0/28"
  }
}

# --- GKE privado en el proyecto de app ---

module "gke" {
  source = "../../../../modules/gke"

  cluster_name               = "${local.name_app}-gke"
  project_id                 = var.app_project_id
  region                     = local.region
  regional                   = var.regional
  network                    = var.network_self_link
  subnetwork                 = var.subnet.self_link
  pods_range_name            = var.subnet.pods_range_name
  services_range_name        = var.subnet.services_range_name
  master_ipv4_cidr_block     = local.master_cidrs[var.env]
  master_authorized_networks = var.master_authorized_networks
  node_service_account       = var.service_accounts["gke_nodes"]
  database_encryption_key    = var.kms_keys["gke"]
  deletion_protection        = var.deletion_protection
  labels                     = var.labels

  node_pools = {
    default = { machine_type = "e2-medium", min_count = 1, max_count = 3 }
  }
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
resource "random_id" "sql" {
  byte_length = 2
}

module "sql" {
  source = "../../../../modules/cloud-sql"

  name                = "${local.name_data}-sql-${random_id.sql.hex}"
  project_id          = var.data_project_id
  region              = local.region
  network             = var.network_self_link
  kms_key_name        = var.kms_keys["sql"]
  ha                  = var.sql_ha
  enable_dr_replica   = var.enable_dr_replica
  dr_kms_key_name     = lookup(var.kms_keys, "sql-dr", null)
  deletion_protection = var.deletion_protection
  labels              = var.labels
}

# --- Bucket CMEK en el proyecto de datos ---

module "storage" {
  source = "../../../../modules/storage"

  name              = "${var.data_project_id}-app"
  project_id        = var.data_project_id
  location          = var.bucket_dual_region ? "US" : "US-CENTRAL1"
  dual_region       = var.bucket_dual_region ? ["US-CENTRAL1", "US-EAST4"] : []
  turbo_replication = var.bucket_dual_region
  kms_key_name      = var.bucket_dual_region ? var.kms_keys["storage-us"] : var.kms_keys["storage"]
  force_destroy     = !var.deletion_protection
  labels            = var.labels
}

resource "google_storage_bucket_iam_member" "app_workload" {
  bucket = module.storage.bucket_name
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${var.service_accounts["app_workload"]}"
}

# --- MIG e2-micro en el proyecto de app ---

module "mig" {
  source = "../../../../modules/compute-mig"

  name                  = local.name_app
  project_id            = var.app_project_id
  region                = local.region
  subnetwork            = var.subnet.self_link
  service_account_email = var.service_accounts["vm"]
  labels                = var.labels
}

# --- Observabilidad: alertas en app; datos y hub en su metrics scope ---

module "observability" {
  source = "../../../../modules/observability"

  project_id            = var.app_project_id
  name_prefix           = "${var.prefix}-${var.env}"
  notification_email    = var.notification_email
  monitored_project_ids = [var.data_project_id, var.hub_project_id]
  labels                = var.labels
}
