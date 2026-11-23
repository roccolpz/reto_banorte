provider "google" {}

module "firewall" {
  source = "../.."

  project_id        = "acme-dev-net-host-0000"
  network           = "projects/acme-dev-net-host-0000/global/networks/acme-dev-net-vpc"
  name_prefix       = "acme-dev-net"
  default_rules     = true
  deny_source_cidrs = ["10.20.0.0/16", "10.30.0.0/16", "10.31.0.0/16"]

  rules = {
    allow-internal = {
      description = "Tráfico interno del entorno."
      ranges      = ["10.10.0.0/16"]
    }
  }

  labels = {
    env         = "dev"
    app         = "network"
    owner       = "network-team"
    cost_center = "infra"
    managed_by  = "terraform"
  }
}
