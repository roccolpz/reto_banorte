locals {
  env    = "dev"
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
  single_project  = try(data.terraform_remote_state.org.outputs.compact_projects, false)
  subnets         = data.terraform_remote_state.network.outputs.subnets
  kms_keys        = data.terraform_remote_state.security.outputs.kms_keys[local.env]
  perimeter_name  = data.terraform_remote_state.security.outputs.perimeter_names[local.env]
  # La SA de este entorno no edita perímetros: 2-security agrega app y datos (ADR 0007-f).
  add_to_perimeter = false
  vpc_sc_enforce   = data.terraform_remote_state.security.outputs.vpc_sc_enforce[local.env]
  labels           = local.labels

  deployer_service_account = data.terraform_remote_state.bootstrap.outputs.stage_service_accounts["5-workloads-${local.env}"]
  secure_tag_values        = data.terraform_remote_state.network.outputs.secure_tag_values
}
