locals {
  region_short = { us-central1 = "usc1", us-east4 = "use4" }[var.region]
  local_name   = "${var.name}-${local.region_short}"
  peer_name    = "${var.peer_name}-${local.region_short}"
  tunnels      = [0, 1]
}

# Secreto IKE por par de túneles. Solo vive en el estado (bucket con CMEK); nunca en código ni en tfvars.
resource "random_password" "secret" {
  count   = length(local.tunnels)
  length  = 32
  special = false
}

resource "google_compute_ha_vpn_gateway" "local" {
  project = var.project_id
  region  = var.region
  name    = "${local.local_name}-vpngw"
  network = var.network
  labels  = var.labels
}

resource "google_compute_ha_vpn_gateway" "peer" {
  project = var.project_id
  region  = var.region
  name    = "${local.peer_name}-vpngw"
  network = var.peer_network
  labels  = var.labels
}

resource "google_compute_router" "local" {
  project = var.project_id
  region  = var.region
  name    = "${local.local_name}-vpn-cr"
  network = var.network

  bgp {
    asn               = var.asn
    advertise_mode    = "CUSTOM"
    advertised_groups = ["ALL_SUBNETS"]

    dynamic "advertised_ip_ranges" {
      for_each = var.advertised_ranges
      content {
        range = advertised_ip_ranges.value
      }
    }
  }
}

resource "google_compute_router" "peer" {
  project = var.project_id
  region  = var.region
  name    = "${local.peer_name}-vpn-cr"
  network = var.peer_network

  bgp {
    asn               = var.peer_asn
    advertise_mode    = "CUSTOM"
    advertised_groups = ["ALL_SUBNETS"]

    dynamic "advertised_ip_ranges" {
      for_each = var.peer_advertised_ranges
      content {
        range = advertised_ip_ranges.value
      }
    }
  }
}

resource "google_compute_vpn_tunnel" "local" {
  count = length(local.tunnels)

  project               = var.project_id
  region                = var.region
  name                  = "${local.local_name}-tun-${count.index}"
  vpn_gateway           = google_compute_ha_vpn_gateway.local.id
  vpn_gateway_interface = count.index
  peer_gcp_gateway      = google_compute_ha_vpn_gateway.peer.id
  shared_secret         = random_password.secret[count.index].result
  router                = google_compute_router.local.id
  labels                = var.labels
}

resource "google_compute_vpn_tunnel" "peer" {
  count = length(local.tunnels)

  project               = var.project_id
  region                = var.region
  name                  = "${local.peer_name}-tun-${count.index}"
  vpn_gateway           = google_compute_ha_vpn_gateway.peer.id
  vpn_gateway_interface = count.index
  peer_gcp_gateway      = google_compute_ha_vpn_gateway.local.id
  shared_secret         = random_password.secret[count.index].result
  router                = google_compute_router.peer.id
  labels                = var.labels
}

resource "google_compute_router_interface" "local" {
  count = length(local.tunnels)

  project    = var.project_id
  region     = var.region
  router     = google_compute_router.local.name
  name       = "${local.local_name}-if-${count.index}"
  ip_range   = "${cidrhost(var.bgp_cidrs[count.index], 1)}/30"
  vpn_tunnel = google_compute_vpn_tunnel.local[count.index].name
}

resource "google_compute_router_interface" "peer" {
  count = length(local.tunnels)

  project    = var.project_id
  region     = var.region
  router     = google_compute_router.peer.name
  name       = "${local.peer_name}-if-${count.index}"
  ip_range   = "${cidrhost(var.bgp_cidrs[count.index], 2)}/30"
  vpn_tunnel = google_compute_vpn_tunnel.peer[count.index].name
}

resource "google_compute_router_peer" "local" {
  count = length(local.tunnels)

  project         = var.project_id
  region          = var.region
  router          = google_compute_router.local.name
  name            = "${local.local_name}-bgp-${count.index}"
  interface       = google_compute_router_interface.local[count.index].name
  peer_ip_address = cidrhost(var.bgp_cidrs[count.index], 2)
  peer_asn        = var.peer_asn
}

resource "google_compute_router_peer" "peer" {
  count = length(local.tunnels)

  project         = var.project_id
  region          = var.region
  router          = google_compute_router.peer.name
  name            = "${local.peer_name}-bgp-${count.index}"
  interface       = google_compute_router_interface.peer[count.index].name
  peer_ip_address = cidrhost(var.bgp_cidrs[count.index], 1)
  peer_asn        = var.asn
}

# Spoke híbrido: va al grupo center de la topología STAR para que los spokes de entorno (edge)
# aprendan las rutas on-prem sin verse entre sí. Requiere el mismo proyecto que el hub.
resource "google_network_connectivity_spoke" "vpn" {
  count = var.ncc_hub_id == null ? 0 : 1

  project  = var.project_id
  location = var.region
  name     = "${local.local_name}-vpn-spoke"
  hub      = var.ncc_hub_id
  group    = "${var.ncc_hub_id}/groups/center"
  labels   = var.labels

  linked_vpn_tunnels {
    uris                       = google_compute_vpn_tunnel.local[*].self_link
    site_to_site_data_transfer = false
    include_import_ranges      = ["ALL_IPV4_RANGES"]
  }
}
