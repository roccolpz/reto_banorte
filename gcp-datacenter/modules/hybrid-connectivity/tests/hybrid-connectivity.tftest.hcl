mock_provider "google" {}
mock_provider "random" {}

variables {
  project_id             = "acme-common-net-hub-0000"
  region                 = "us-central1"
  name                   = "acme-common-net-hub"
  peer_name              = "acme-onprem-sim"
  network                = "https://www.googleapis.com/compute/v1/projects/acme-common-net-hub-0000/global/networks/acme-common-net-hub-vpc"
  peer_network           = "https://www.googleapis.com/compute/v1/projects/acme-common-net-hub-0000/global/networks/acme-onprem-sim-vpc"
  advertised_ranges      = ["10.0.0.0/8", "35.199.192.0/19"]
  peer_advertised_ranges = ["192.168.0.0/16"]
  ncc_hub_id             = "projects/acme-common-net-hub-0000/locations/global/hubs/acme-common-net-hub"
  create_ncc_spoke       = true
  labels = {
    env         = "common"
    app         = "network"
    owner       = "network-team"
    cost_center = "infra"
    managed_by  = "terraform"
  }
}

run "ha_vpn_pair_with_bgp" {
  command = plan

  assert {
    condition     = length(google_compute_vpn_tunnel.local) == 2 && length(google_compute_vpn_tunnel.peer) == 2
    error_message = "Debe haber dos túneles por lado."
  }

  assert {
    condition     = google_compute_router.local.bgp[0].asn == 64514 && google_compute_router.peer.bgp[0].asn == 65001
    error_message = "ASN: hub 64514, on-prem 65001."
  }

  assert {
    condition     = toset([for r in google_compute_router.local.bgp[0].advertised_ip_ranges : r.range]) == toset(["10.0.0.0/8", "35.199.192.0/19"])
    error_message = "El hub debe anunciar 10.0.0.0/8 y 35.199.192.0/19."
  }

  assert {
    condition     = google_compute_router.local.bgp[0].advertise_mode == "CUSTOM" && contains(google_compute_router.local.bgp[0].advertised_groups, "ALL_SUBNETS")
    error_message = "El router del hub debe usar anuncio CUSTOM incluyendo ALL_SUBNETS."
  }

  assert {
    condition     = google_compute_router_peer.local[0].peer_ip_address == "169.254.0.2" && google_compute_router_peer.peer[0].peer_ip_address == "169.254.0.1"
    error_message = "Las sesiones BGP deben usar .1 (GCP) y .2 (on-prem) del /30."
  }

  assert {
    condition     = google_compute_router_peer.local[1].peer_asn == 65001 && google_compute_router_peer.peer[1].peer_asn == 64514
    error_message = "Cada lado debe apuntar al ASN del otro."
  }

  assert {
    condition     = google_compute_vpn_tunnel.local[0].vpn_gateway_interface == 0 && google_compute_vpn_tunnel.local[1].vpn_gateway_interface == 1
    error_message = "Cada túnel debe usar una interfaz distinta del HA VPN."
  }

  assert {
    condition     = random_password.secret[0].length >= 32 && random_password.secret[0].special == false
    error_message = "El secreto compartido debe generarse con random_password (>= 32 caracteres)."
  }
}

run "registers_hybrid_spoke_in_center_group" {
  command = plan

  assert {
    condition     = length(google_network_connectivity_spoke.vpn) == 1
    error_message = "Con ncc_hub_id debe crearse un spoke híbrido."
  }

  assert {
    condition     = google_network_connectivity_spoke.vpn[0].group == "${var.ncc_hub_id}/groups/center"
    error_message = "El spoke híbrido debe ir al grupo center de la topología STAR."
  }

  assert {
    condition     = google_network_connectivity_spoke.vpn[0].linked_vpn_tunnels[0].site_to_site_data_transfer == false && google_network_connectivity_spoke.vpn[0].linked_vpn_tunnels[0].include_import_ranges == tolist(["ALL_IPV4_RANGES"])
    error_message = "El spoke híbrido debe importar todas las rutas del hub y no hacer site-to-site."
  }
}

run "no_spoke_without_hub" {
  command = plan

  variables {
    create_ncc_spoke = false
  }

  assert {
    condition     = length(google_network_connectivity_spoke.vpn) == 0
    error_message = "Con create_ncc_spoke = false no debe crearse spoke."
  }
}

run "spoke_requires_hub_id" {
  command = plan

  variables {
    ncc_hub_id = null
  }

  expect_failures = [var.create_ncc_spoke]
}

run "rejects_bad_bgp_cidrs" {
  command = plan

  variables {
    bgp_cidrs = ["10.0.0.0/30", "169.254.1.0/30"]
  }

  expect_failures = [var.bgp_cidrs]
}
