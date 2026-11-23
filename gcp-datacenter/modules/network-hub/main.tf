locals {
  name         = "${var.prefix}-common-net-hub"
  region_short = { us-central1 = "usc1", us-east4 = "use4" }
}

resource "google_compute_network" "hub" {
  project                 = var.project_id
  name                    = "${local.name}-vpc"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
}

resource "google_compute_subnetwork" "hub" {
  for_each = var.subnets

  project                  = var.project_id
  network                  = google_compute_network.hub.id
  region                   = each.key
  name                     = "${local.name}-${local.region_short[each.key]}"
  ip_cidr_range            = each.value
  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# STAR: los spokes híbridos (VPN) van al grupo center y los VPC spokes de entorno al grupo edge.
# Los spokes edge solo aprenden rutas del center, así dev/qa/prod llegan a on-prem sin verse entre sí.
resource "google_network_connectivity_hub" "hub" {
  project         = var.project_id
  name            = local.name
  description     = "Hub de NCC: on-prem (center) y entornos (edge)."
  preset_topology = "STAR"
  labels          = var.labels
}

resource "google_network_connectivity_group" "edge" {
  project = var.project_id
  hub     = google_network_connectivity_hub.hub.id
  name    = "edge"
  labels  = var.labels

  dynamic "auto_accept" {
    for_each = length(var.spoke_projects) > 0 ? [1] : []
    content {
      auto_accept_projects = var.spoke_projects
    }
  }
}

resource "google_dns_managed_zone" "corp_forwarding" {
  project     = var.project_id
  name        = "${local.name}-corp-fwd"
  dns_name    = var.corp_dns_domain
  description = "Reenvío del dominio corporativo hacia el DNS on-prem por HA VPN."
  visibility  = "private"
  labels      = var.labels

  private_visibility_config {
    networks {
      network_url = google_compute_network.hub.id
    }
  }

  forwarding_config {
    dynamic "target_name_servers" {
      for_each = var.onprem_dns_target_ips
      content {
        ipv4_address = target_name_servers.value
      }
    }
  }
}

# Puntos de entrada privados para que on-prem resuelva nombres de GCP.
resource "google_dns_policy" "inbound" {
  project                   = var.project_id
  name                      = "${local.name}-inbound"
  enable_inbound_forwarding = true
  enable_logging            = true

  networks {
    network_url = google_compute_network.hub.id
  }
}
