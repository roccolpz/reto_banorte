locals {
  env    = "qa"
  labels = merge(var.labels, { env = local.env, managed_by = "terraform" })
}

data "terraform_remote_state" "bootstrap" {
  backend = "gcs"
  config  = { bucket = var.state_bucket, prefix = "0-bootstrap" }
}

data "terraform_remote_state" "org" {
  backend = "gcs"
  config  = { bucket = var.state_bucket, prefix = "1-org" }
}

data "terraform_remote_state" "security" {
  backend = "gcs"
  config  = { bucket = var.state_bucket, prefix = "2-security" }
}

data "terraform_remote_state" "network" {
  backend = "gcs"
  config  = { bucket = var.state_bucket, prefix = "3-networks/${local.env}" }
}

module "env" {
  source = "../../modules/env"
  providers = {
    google      = google
    google.acm  = google.acm
    google-beta = google-beta
  }

  env             = local.env
  prefix          = var.prefix
  suffix          = var.suffix
  billing_account = var.billing_account
  folder_id       = data.terraform_remote_state.org.outputs.folder_ids[local.env]
  host_project_id = data.terraform_remote_state.network.outputs.host_project_id
  subnets         = data.terraform_remote_state.network.outputs.subnets
  kms_keys        = data.terraform_remote_state.security.outputs.kms_keys[local.env]
  perimeter_name  = data.terraform_remote_state.security.outputs.perimeter_names[local.env]
  vpc_sc_enforce  = var.vpc_sc_enforce
  labels          = local.labels

  deployer_service_account = lookup(data.terraform_remote_state.bootstrap.outputs.stage_service_accounts, "5-workloads-${local.env}", null)
}
