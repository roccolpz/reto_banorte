# Red mínima compartida por los fixtures de Terratest: VPC, una subred con rangos secundarios
# (pods y services, como 3-networks) y, opcional, Private Service Access para Cloud SQL.
terraform {
  required_version = ">= 1.9"
  required_providers {
    google = { source = "hashicorp/google", version = ">= 6.0, < 7.0" }
  }
}

variable "project_id" {
  description = "Proyecto efímero de la prueba."
  type        = string
}

variable "name" {
  description = "Nombre de la VPC y de la subred."
  type        = string
}

variable "region" {
  description = "Región de la subred."
  type        = string
}

variable "psa" {
  description = "true: reserva 10.10.128.0/20 y crea la conexión de Private Service Access."
  type        = bool
  default     = false
}

locals {
  psa_cidr = "10.10.128.0/20"
}

resource "google_compute_network" "this" {
  project                 = var.project_id
  name                    = var.name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "this" {
  project                  = var.project_id
  name                     = var.name
  region                   = var.region
  network                  = google_compute_network.this.id
  ip_cidr_range            = "10.10.0.0/20"
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.10.64.0/18"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.10.32.0/22"
  }

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_global_address" "psa" {
  count         = var.psa ? 1 : 0
  project       = var.project_id
  name          = "${var.name}-psa"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = split("/", local.psa_cidr)[0]
  prefix_length = tonumber(split("/", local.psa_cidr)[1])
  network       = google_compute_network.this.id
}

resource "google_service_networking_connection" "psa" {
  count                   = var.psa ? 1 : 0
  network                 = google_compute_network.this.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.psa[0].name]

  # El proyecto efímero se borra completo; sin esto el destroy falla mientras Cloud SQL libera el peering.
  deletion_policy = "ABANDON"
}

output "network_id" {
  description = "ID de la VPC. Espera a la conexión de PSA para que Cloud SQL no se cree antes."
  value       = google_compute_network.this.id
  depends_on  = [google_service_networking_connection.psa]
}

output "network_self_link" {
  description = "Self link de la VPC."
  value       = google_compute_network.this.self_link
}

output "subnetwork_id" {
  description = "ID de la subred."
  value       = google_compute_subnetwork.this.id
}

output "psa_cidr" {
  description = "Rango reservado para Private Service Access (null sin psa)."
  value       = var.psa ? local.psa_cidr : null
}
