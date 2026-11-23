# Módulo local compartido por envs/{dev,qa,prod}: los entornos solo difieren en var.env.

data "terraform_remote_state" "org" {
  backend = "gcs"
  config  = { bucket = var.state_bucket, prefix = "1-org" }
}

data "terraform_remote_state" "hub" {
  backend = "gcs"
  config  = { bucket = var.state_bucket, prefix = "3-networks/hub" }
}

locals {
  hub             = data.terraform_remote_state.hub.outputs
  host_project_id = data.terraform_remote_state.org.outputs.net_host_project_ids[var.env]

  # Segundo octeto por entorno y región (contrato §5).
  octets = {
    dev  = { us-central1 = 10 }
    qa   = { us-central1 = 20 }
    prod = { us-central1 = 30, us-east4 = 31 }
  }

  regions = {
    for region, x in local.octets[var.env] : region => {
      app_cidr      = "10.${x}.0.0/20"
      services_cidr = "10.${x}.32.0/22"
      proxy_cidr    = "10.${x}.48.0/23"
      pods_cidr     = "10.${x}.64.0/18"
    }
  }

  # PSA es global a la VPC: un solo rango, con el octeto de us-central1.
  psa_cidr = "10.${local.octets[var.env]["us-central1"]}.128.0/20"

  own_cidrs  = [for x in values(local.octets[var.env]) : "10.${x}.0.0/16"]
  deny_cidrs = flatten([for e, m in local.octets : [for x in values(m) : "10.${x}.0.0/16"] if e != var.env])
}

module "spoke" {
  source = "../../../../modules/network-spoke"

  project_id            = local.host_project_id
  prefix                = var.prefix
  env                   = var.env
  regions               = local.regions
  psa_cidr              = local.psa_cidr
  corp_dns_domain       = local.hub.corp_dns_domain
  hub_network_self_link = local.hub.hub_network_self_link
  ncc_hub_id            = local.hub.ncc_hub_id
  labels                = var.labels
}

module "firewall" {
  source = "../../../../modules/firewall"

  project_id        = local.host_project_id
  network           = module.spoke.network_self_link
  name_prefix       = "${var.prefix}-${var.env}-net"
  default_rules     = true
  onprem_cidrs      = local.hub.onprem_cidrs
  deny_source_cidrs = local.deny_cidrs
  labels            = var.labels

  rules = {
    allow-internal = {
      description = "Tráfico interno del entorno (subredes, pods, services, PSA)."
      ranges      = local.own_cidrs
    }
  }
}
