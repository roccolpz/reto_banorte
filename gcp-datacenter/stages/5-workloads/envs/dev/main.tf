locals {
  env    = "dev"
  labels = merge(var.labels, { env = local.env, managed_by = "terraform" })

  projects = data.terraform_remote_state.projects.outputs
  network  = data.terraform_remote_state.network.outputs
}

data "terraform_remote_state" "security" {
  backend = "gcs"
  config  = { bucket = var.state_bucket, prefix = "2-security" }
}

data "terraform_remote_state" "hub" {
  backend = "gcs"
  config  = { bucket = var.state_bucket, prefix = "3-networks/hub" }
}

data "terraform_remote_state" "network" {
  backend = "gcs"
  config  = { bucket = var.state_bucket, prefix = "3-networks/${local.env}" }
}

# shortcut: 3-networks publica solo los valores (tagValues/ID) y resource_manager_tags pide también la llave;
# se busca por el nombre que le da 3-networks (<prefix>-<env>-net-fw). Cambiar a una salida secure_tag_keys cuando el contrato la tenga (ADR 0019-i).
data "google_tags_tag_key" "firewall" {
  parent     = "projects/${local.network.host_project_id}"
  short_name = "${var.prefix}-${local.env}-net-fw"
}

data "terraform_remote_state" "projects" {
  backend = "gcs"
  config  = { bucket = var.state_bucket, prefix = "4-projects/${local.env}" }
}

module "env" {
  source = "../../modules/env"

  env                        = local.env
  prefix                     = var.prefix
  app_project_id             = local.projects.app_project_id
  data_project_id            = local.projects.data_project_id
  service_accounts           = local.projects.service_accounts
  hub_project_id             = data.terraform_remote_state.hub.outputs.hub_project_id
  network_self_link          = local.network.network_self_link
  subnets                    = local.network.subnets
  primary_region             = var.primary_region
  dr_region                  = var.dr_region
  secure_tag_key             = data.google_tags_tag_key.firewall.id
  secure_tag_values          = local.network.secure_tag_values
  kms_keys                   = data.terraform_remote_state.security.outputs.kms_keys[local.env]
  regional                   = coalesce(var.regional, local.env == "prod")
  deletion_protection        = coalesce(var.deletion_protection, local.env == "prod")
  sql_ha                     = var.sql_ha
  enable_dr_replica          = var.enable_dr_replica
  bucket_dual_region         = var.bucket_dual_region
  enable_dr_cluster          = var.enable_dr_cluster
  gke_node_pools             = var.gke_node_pools
  sql_tier                   = var.sql_tier
  image_family               = var.image_family
  uptime_check_host          = var.uptime_check_host
  notification_email         = var.notification_email
  ksa_namespace              = var.ksa_namespace
  ksa_name                   = var.ksa_name
  master_authorized_networks = var.master_authorized_networks
  labels                     = local.labels
}
