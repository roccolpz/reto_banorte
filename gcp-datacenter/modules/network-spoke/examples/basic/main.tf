provider "google" {}

module "spoke" {
  source = "../.."

  project_id = "acme-dev-net-host-0000"
  env        = "dev"
  regions = {
    us-central1 = {
      app_cidr      = "10.10.0.0/20"
      services_cidr = "10.10.32.0/22"
      proxy_cidr    = "10.10.48.0/23"
      pods_cidr     = "10.10.64.0/18"
    }
  }
  psa_cidr              = "10.10.128.0/20"
  hub_network_self_link = "https://www.googleapis.com/compute/v1/projects/acme-common-net-hub-0000/global/networks/acme-common-net-hub-vpc"
  ncc_hub_id            = "projects/acme-common-net-hub-0000/locations/global/hubs/acme-common-net-hub"

  labels = {
    env         = "dev"
    app         = "network"
    owner       = "network-team"
    cost_center = "infra"
    managed_by  = "terraform"
  }
}
