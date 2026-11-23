locals {
  env    = "prod"
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
  subnet                     = local.network.subnets["us-central1"]
  kms_keys                   = data.terraform_remote_state.security.outputs.kms_keys[local.env]
  regional                   = coalesce(var.regional, local.env == "prod")
  deletion_protection        = coalesce(var.deletion_protection, local.env == "prod")
  sql_ha                     = var.sql_ha
  enable_dr_replica          = var.enable_dr_replica
  bucket_dual_region         = var.bucket_dual_region
  notification_email         = var.notification_email
  ksa_namespace              = var.ksa_namespace
  ksa_name                   = var.ksa_name
  master_authorized_networks = var.master_authorized_networks
  labels                     = local.labels
}
