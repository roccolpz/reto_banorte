mock_provider "google" {}

variables {
  project_id            = "acme-common-net-hub-0000"
  onprem_dns_target_ips = ["192.168.10.2"]
  spoke_projects        = ["acme-dev-net-host-0000", "acme-qa-net-host-0000"]
  labels = {
    env         = "common"
    app         = "network"
    owner       = "network-team"
    cost_center = "infra"
    managed_by  = "terraform"
  }
}

run "hub_network_and_ncc" {
  command = plan

  assert {
    condition     = google_compute_network.hub.name == "acme-common-net-hub-vpc" && google_compute_network.hub.routing_mode == "GLOBAL" && google_compute_network.hub.auto_create_subnetworks == false
    error_message = "La VPC del hub debe ser custom, con enrutamiento global y nombre acme-common-net-hub-vpc."
  }

  assert {
    condition     = google_compute_subnetwork.hub["us-central1"].ip_cidr_range == "10.0.0.0/24" && google_compute_subnetwork.hub["us-east4"].ip_cidr_range == "10.0.1.0/24"
    error_message = "Subredes del hub: 10.0.0.0/24 us-central1 y 10.0.1.0/24 us-east4."
  }

  assert {
    condition     = google_network_connectivity_hub.hub.preset_topology == "STAR"
    error_message = "El hub de NCC debe usar topología STAR para aislar entornos."
  }

  assert {
    condition     = google_network_connectivity_group.edge.name == "edge" && toset(google_network_connectivity_group.edge.auto_accept[0].auto_accept_projects) == toset(var.spoke_projects)
    error_message = "El grupo edge debe aceptar automáticamente los proyectos host de los entornos."
  }
}

run "hub_dns" {
  command = plan

  assert {
    condition     = google_dns_managed_zone.corp_forwarding.dns_name == "corp.acme.internal." && google_dns_managed_zone.corp_forwarding.visibility == "private"
    error_message = "Debe existir una zona privada de reenvío para corp.acme.internal."
  }

  assert {
    condition     = [for t in google_dns_managed_zone.corp_forwarding.forwarding_config[0].target_name_servers : t.ipv4_address] == ["192.168.10.2"]
    error_message = "La zona de reenvío debe apuntar a los DNS on-prem."
  }

  assert {
    condition     = google_dns_policy.inbound.enable_inbound_forwarding == true
    error_message = "El hub debe tener una inbound server policy."
  }
}

run "rejects_onprem_overlap" {
  command = plan

  variables {
    subnets = { us-central1 = "192.168.1.0/24" }
  }

  expect_failures = [var.subnets]
}

run "rejects_empty_dns_targets" {
  command = plan

  variables {
    onprem_dns_target_ips = []
  }

  expect_failures = [var.onprem_dns_target_ips]
}
