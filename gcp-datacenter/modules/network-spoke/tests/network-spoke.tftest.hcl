mock_provider "google" {}

variables {
  project_id = "acme-prod-net-host-0000"
  env        = "prod"
  regions = {
    us-central1 = { app_cidr = "10.30.0.0/20", services_cidr = "10.30.32.0/22", proxy_cidr = "10.30.48.0/23", pods_cidr = "10.30.64.0/18" }
    us-east4    = { app_cidr = "10.31.0.0/20", services_cidr = "10.31.32.0/22", proxy_cidr = "10.31.48.0/23", pods_cidr = "10.31.64.0/18" }
  }
  psa_cidr              = "10.30.128.0/20"
  hub_network_self_link = "https://www.googleapis.com/compute/v1/projects/acme-common-net-hub-0000/global/networks/acme-common-net-hub-vpc"
  ncc_hub_id            = "projects/acme-common-net-hub-0000/locations/global/hubs/acme-common-net-hub"
  labels = {
    env         = "prod"
    app         = "network"
    owner       = "network-team"
    cost_center = "infra"
    managed_by  = "terraform"
  }
}

run "vpc_and_subnets" {
  command = plan

  assert {
    condition     = google_compute_network.this.name == "acme-prod-net-vpc" && google_compute_network.this.routing_mode == "GLOBAL" && google_compute_network.this.auto_create_subnetworks == false
    error_message = "VPC custom, enrutamiento global, nombre acme-prod-net-vpc."
  }

  assert {
    condition     = google_compute_subnetwork.app["us-central1"].name == "acme-prod-net-app-usc1" && google_compute_subnetwork.app["us-east4"].ip_cidr_range == "10.31.0.0/20"
    error_message = "Una subred app por región con el CIDR del contrato."
  }

  assert {
    condition     = google_compute_subnetwork.app["us-central1"].private_ip_google_access && google_compute_subnetwork.app["us-central1"].log_config[0].flow_sampling == 0.5
    error_message = "Subred app con Private Google Access y flow logs al 50 %."
  }

  assert {
    condition = { for s in google_compute_subnetwork.app["us-central1"].secondary_ip_range : s.range_name => s.ip_cidr_range } == {
      pods     = "10.30.64.0/18"
      services = "10.30.32.0/22"
    }
    error_message = "Rangos secundarios pods y services."
  }

  assert {
    condition     = google_compute_subnetwork.proxy["us-east4"].purpose == "REGIONAL_MANAGED_PROXY" && google_compute_subnetwork.proxy["us-east4"].role == "ACTIVE"
    error_message = "Subred proxy-only REGIONAL_MANAGED_PROXY activa por región."
  }

  assert {
    condition     = length(google_compute_router_nat.this) == 2 && google_compute_router_nat.this["us-east4"].source_subnetwork_ip_ranges_to_nat == "LIST_OF_SUBNETWORKS"
    error_message = "Un Cloud NAT por región, solo para las subredes app."
  }
}

run "psa_shared_vpc_dns_ncc" {
  command = plan

  assert {
    condition     = google_compute_global_address.psa[0].purpose == "VPC_PEERING" && google_compute_global_address.psa[0].address == "10.30.128.0" && google_compute_global_address.psa[0].prefix_length == 20
    error_message = "Rango PSA 10.30.128.0/20 con propósito VPC_PEERING."
  }

  assert {
    condition     = google_service_networking_connection.psa[0].service == "servicenetworking.googleapis.com"
    error_message = "Conexión de Service Networking para PSA."
  }

  assert {
    condition     = length(google_compute_shared_vpc_host_project.this) == 1
    error_message = "El proyecto debe habilitarse como host de Shared VPC."
  }

  assert {
    condition     = google_dns_managed_zone.private.dns_name == "prod.gcp.acme.internal." && google_dns_managed_zone.private.visibility == "private"
    error_message = "Zona privada prod.gcp.acme.internal."
  }

  assert {
    condition     = google_dns_managed_zone.corp_peering[0].dns_name == "corp.acme.internal." && google_dns_managed_zone.corp_peering[0].peering_config[0].target_network[0].network_url == var.hub_network_self_link
    error_message = "Zona de DNS peering de corp.acme.internal hacia el hub."
  }

  assert {
    condition     = google_network_connectivity_spoke.vpc[0].location == "global" && google_network_connectivity_spoke.vpc[0].group == "${var.ncc_hub_id}/groups/edge"
    error_message = "VPC spoke global en el grupo edge."
  }
}

run "standalone_without_hub" {
  command = plan

  variables {
    regions               = { us-central1 = { app_cidr = "10.10.0.0/20", services_cidr = "10.10.32.0/22", proxy_cidr = "10.10.48.0/23", pods_cidr = "10.10.64.0/18" } }
    env                   = "dev"
    psa_cidr              = null
    hub_network_self_link = null
    ncc_hub_id            = null
  }

  assert {
    condition     = length(google_network_connectivity_spoke.vpc) == 0 && length(google_dns_managed_zone.corp_peering) == 0 && length(google_compute_global_address.psa) == 0
    error_message = "Sin hub ni PSA no deben crearse spoke, peering ni PSA."
  }
}

run "rejects_onprem_overlap" {
  command = plan

  variables {
    regions = { us-central1 = { app_cidr = "192.168.20.0/24", services_cidr = "10.10.32.0/22", proxy_cidr = "10.10.48.0/23", pods_cidr = "10.10.64.0/18" } }
  }

  expect_failures = [var.regions]
}

run "rejects_bad_env" {
  command = plan

  variables {
    env = "test"
  }

  expect_failures = [var.env]
}
