locals {
  env    = "prod"
  labels = merge(var.labels, { env = local.env, managed_by = "terraform" })
}

data "terraform_remote_state" "org" {
  backend = "gcs"
  config  = { bucket = var.state_bucket, prefix = "1-org" }
}

data "terraform_remote_state" "hub" {
  backend = "gcs"
  config  = { bucket = var.state_bucket, prefix = "3-networks/hub" }
}

# Toda la lógica vive en el módulo compartido; la raíz lee el estado remoto y pasa valores planos.
module "env" {
  source = "../../modules/env"

  env                   = local.env
  host_project_id       = data.terraform_remote_state.org.outputs.net_host_project_ids[local.env]
  hub_network_self_link = data.terraform_remote_state.hub.outputs.hub_network_self_link
  ncc_hub_id            = data.terraform_remote_state.hub.outputs.ncc_hub_id
  corp_dns_domain       = data.terraform_remote_state.hub.outputs.corp_dns_domain
  onprem_cidrs          = data.terraform_remote_state.hub.outputs.onprem_cidrs
  prefix                = var.prefix
  labels                = local.labels
}
