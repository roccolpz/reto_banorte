provider "google" {}

module "vpn" {
  source = "../.."

  project_id             = "acme-common-net-hub-0000"
  region                 = "us-central1"
  name                   = "acme-common-net-hub"
  peer_name              = "acme-onprem-sim"
  network                = "projects/acme-common-net-hub-0000/global/networks/acme-common-net-hub-vpc"
  peer_network           = "projects/acme-common-net-hub-0000/global/networks/acme-onprem-sim-vpc"
  advertised_ranges      = ["10.0.0.0/8", "35.199.192.0/19"]
  peer_advertised_ranges = ["192.168.0.0/16"]
  ncc_hub_id             = "projects/acme-common-net-hub-0000/locations/global/hubs/acme-common-net-hub"

  labels = {
    env         = "common"
    app         = "network"
    owner       = "network-team"
    cost_center = "infra"
    managed_by  = "terraform"
  }
}
