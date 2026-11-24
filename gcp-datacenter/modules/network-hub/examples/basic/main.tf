provider "google" {}

module "hub" {
  source = "../.."

  project_id            = "acme-common-net-hub-0000"
  onprem_dns_target_ips = ["192.168.10.2"]
  spoke_projects        = ["acme-dev-net-host-0000", "acme-qa-net-host-0000", "acme-prod-net-host-0000"]

  labels = {
    env         = "common"
    app         = "network"
    owner       = "network-team"
    cost_center = "infra"
    managed_by  = "terraform"
  }
}
