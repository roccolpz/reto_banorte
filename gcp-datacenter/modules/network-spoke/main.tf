locals {
  name         = "${var.prefix}-${var.env}-net"
  region_short = { us-central1 = "usc1", us-east4 = "use4" }
  dns_domain   = coalesce(var.dns_domain, "${var.env}.gcp.${var.prefix}.internal.")
}

resource "google_compute_network" "this" {
  project                 = var.project_id
  name                    = "${local.name}-vpc"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
}

resource "google_compute_shared_vpc_host_project" "this" {
  count   = var.enable_shared_vpc_host ? 1 : 0
  project = var.project_id
}

resource "google_compute_subnetwork" "app" {
  for_each = var.regions

  project                  = var.project_id
  network                  = google_compute_network.this.id
  region                   = each.key
  name                     = "${local.name}-app-${local.region_short[each.key]}"
  ip_cidr_range            = each.value.app_cidr
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = each.value.pods_cidr
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = each.value.services_cidr
  }

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = var.flow_sampling
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# Reservada para proxies de balanceadores regionales (no aloja VMs).
resource "google_compute_subnetwork" "proxy" {
  for_each = var.regions

  project       = var.project_id
  network       = google_compute_network.this.id
  region        = each.key
  name          = "${local.name}-proxy-${local.region_short[each.key]}"
  ip_cidr_range = each.value.proxy_cidr
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
}

resource "google_compute_router" "this" {
  for_each = var.regions

  project = var.project_id
  region  = each.key
  name    = "${local.name}-cr-${local.region_short[each.key]}"
  network = google_compute_network.this.id
}

resource "google_compute_router_nat" "this" {
  for_each = var.regions

  project                            = var.project_id
  region                             = each.key
  name                               = "${local.name}-nat-${local.region_short[each.key]}"
  router                             = google_compute_router.this[each.key].name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.app[each.key].id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

resource "google_compute_global_address" "psa" {
  count = var.psa_cidr == null ? 0 : 1

  project       = var.project_id
  name          = "${local.name}-psa"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = cidrhost(var.psa_cidr, 0)
  prefix_length = tonumber(split("/", var.psa_cidr)[1])
  network       = google_compute_network.this.id
  labels        = var.labels
}

resource "google_service_networking_connection" "psa" {
  count = var.psa_cidr == null ? 0 : 1

  network                 = google_compute_network.this.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.psa[0].name]
}

resource "google_dns_managed_zone" "private" {
  project     = var.project_id
  name        = "${local.name}-private"
  dns_name    = local.dns_domain
  description = "Zona privada del entorno ${var.env}."
  visibility  = "private"
  labels      = var.labels

  private_visibility_config {
    networks {
      network_url = google_compute_network.this.id
    }
  }
}

# El dominio corporativo se resuelve en el hub, que lo reenvía a on-prem.
resource "google_dns_managed_zone" "corp_peering" {
  count = var.hub_network_self_link == null ? 0 : 1

  project     = var.project_id
  name        = "${local.name}-corp-peering"
  dns_name    = var.corp_dns_domain
  description = "DNS peering de ${var.corp_dns_domain} hacia la VPC del hub."
  visibility  = "private"
  labels      = var.labels

  private_visibility_config {
    networks {
      network_url = google_compute_network.this.id
    }
  }

  peering_config {
    target_network {
      network_url = var.hub_network_self_link
    }
  }
}

# Grupo edge de la topología STAR: aprende rutas on-prem (center) pero no las de otros entornos.
resource "google_network_connectivity_spoke" "vpc" {
  count = var.ncc_hub_id == null ? 0 : 1

  project  = var.project_id
  location = "global"
  name     = "${local.name}-spoke"
  hub      = var.ncc_hub_id
  group    = "${var.ncc_hub_id}/groups/edge"
  labels   = var.labels

  linked_vpc_network {
    uri = google_compute_network.this.self_link
  }
}
