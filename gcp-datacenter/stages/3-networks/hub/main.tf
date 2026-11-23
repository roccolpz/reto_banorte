data "terraform_remote_state" "org" {
  backend = "gcs"
  config  = { bucket = var.state_bucket, prefix = "1-org" }
}

locals {
  hub_project_id  = data.terraform_remote_state.org.outputs.common_project_ids["net_hub"]
  spoke_projects  = values(data.terraform_remote_state.org.outputs.net_host_project_ids)
  labels          = merge(var.labels, { env = "common", managed_by = "terraform" })
  onprem_name     = "${var.prefix}-onprem-sim"
  onprem_cidrs    = ["192.168.0.0/16"]
  corp_dns_domain = "corp.acme.internal."

  # Destino del reenvío DNS: override explícito o la IP del forwarder entrante de onprem-sim.
  onprem_dns_target_ips = coalescelist(var.onprem_dns_target_ips, data.google_compute_addresses.onprem_dns.addresses[*].address)
}

# --- Hub: VPC, NCC (STAR), reenvío DNS y política entrante ---
module "hub" {
  source = "../../../modules/network-hub"

  project_id            = local.hub_project_id
  prefix                = var.prefix
  corp_dns_domain       = local.corp_dns_domain
  onprem_dns_target_ips = local.onprem_dns_target_ips
  spoke_projects        = local.spoke_projects
  labels                = local.labels
}

# --- On-prem simulado (ADR 0001). Vive en el proyecto del hub: NCC exige que los túneles
# de un spoke híbrido estén en el mismo proyecto que el hub. ---
resource "google_compute_network" "onprem" {
  project                 = local.hub_project_id
  name                    = "${local.onprem_name}-vpc"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
}

resource "google_compute_subnetwork" "onprem" {
  project                  = local.hub_project_id
  name                     = "${local.onprem_name}-usc1"
  region                   = "us-central1"
  network                  = google_compute_network.onprem.id
  ip_cidr_range            = "192.168.10.0/24"
  private_ip_google_access = true

  log_config {
    flow_sampling = 0.5
    metadata      = "INCLUDE_ALL_METADATA"
  }
}

module "onprem_firewall" {
  source = "../../../modules/firewall"

  project_id  = local.hub_project_id
  network     = google_compute_network.onprem.self_link
  name_prefix = local.onprem_name
  labels      = local.labels

  rules = {
    allow-gcp = {
      description = "Tráfico desde GCP por la VPN, incluidas las consultas reenviadas por Cloud DNS (35.199.192.0/19)."
      ranges      = ["10.0.0.0/8", "35.199.192.0/19"]
    }
    allow-iap = {
      description = "SSH y RDP por IAP."
      ranges      = ["35.235.240.0/20"]
      protocols   = [{ protocol = "tcp", ports = ["22", "3389"] }]
    }
  }
}

# Zona "corporativa" que on-prem sirve; el hub la consulta por reenvío.
resource "google_dns_managed_zone" "onprem_corp" {
  project     = local.hub_project_id
  name        = "${local.onprem_name}-corp"
  dns_name    = local.corp_dns_domain
  description = "Zona corporativa simulada de on-prem."
  visibility  = "private"
  labels      = local.labels

  private_visibility_config {
    networks {
      network_url = google_compute_network.onprem.id
    }
  }
}

resource "google_dns_record_set" "onprem_test" {
  project      = local.hub_project_id
  managed_zone = google_dns_managed_zone.onprem_corp.name
  name         = "app.${local.corp_dns_domain}"
  type         = "A"
  ttl          = 300
  rrdatas      = ["192.168.10.10"]
}

# Forwarder entrante de onprem-sim: hace de "DNS on-prem" para el reenvío del hub.
resource "google_dns_policy" "onprem_inbound" {
  project                   = local.hub_project_id
  name                      = "${local.onprem_name}-inbound"
  enable_inbound_forwarding = true
  enable_logging            = true

  networks {
    network_url = google_compute_network.onprem.id
  }
}

# GCP reserva una IP DNS_RESOLVER por subred al crear la política; se lee después de crearla.
data "google_compute_addresses" "onprem_dns" {
  project = local.hub_project_id
  region  = "us-central1"
  filter  = "(purpose = \"DNS_RESOLVER\") AND (subnetwork = \"${google_compute_subnetwork.onprem.self_link}\")"

  depends_on = [google_dns_policy.onprem_inbound]
}

# --- HA VPN hub <-> onprem-sim por región, registrada como spoke híbrido (grupo center) ---
module "vpn" {
  source   = "../../../modules/hybrid-connectivity"
  for_each = toset(var.vpn_regions)

  project_id             = local.hub_project_id
  region                 = each.key
  name                   = "${var.prefix}-common-net-hub"
  peer_name              = local.onprem_name
  network                = module.hub.network_self_link
  peer_network           = google_compute_network.onprem.self_link
  advertised_ranges      = ["10.0.0.0/8", "35.199.192.0/19"]
  peer_advertised_ranges = local.onprem_cidrs
  # Dos /30 de enlace BGP distintos por región.
  bgp_cidrs        = [for i in [0, 1] : "169.254.${2 * index(var.vpn_regions, each.key) + i}.0/30"]
  ncc_hub_id       = module.hub.ncc_hub_id
  create_ncc_spoke = true
  labels           = local.labels
}
