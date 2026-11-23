# Fixture de Terratest para modules/hybrid-connectivity: lo aplica y destruye una prueba de test/integration/modules_test.go
# en un proyecto efímero. No es una raíz de etapa: CI solo lo valida (job terratest-compile).
terraform {
  required_version = ">= 1.9"
  required_providers {
    google = { source = "hashicorp/google", version = ">= 6.0, < 7.0" }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

variable "project_id" {
  description = "Proyecto efímero de la corrida (TEST_PROJECT_ID)."
  type        = string
}

variable "suffix" {
  description = "Sufijo aleatorio por prueba, para que los nombres no choquen entre corridas."
  type        = string
}

variable "region" {
  description = "Región de la prueba."
  type        = string
  default     = "us-central1"
}

locals {
  labels = {
    env         = "dev"
    app         = "terratest"
    owner       = "plataforma"
    cost_center = "ti-001"
    managed_by  = "terraform"
  }
}

# Dos VPC sin subredes bastan para el HA VPN y los Cloud Router.
resource "google_compute_network" "local" {
  name                    = "tt-vpn-${var.suffix}"
  auto_create_subnetworks = false
}

resource "google_compute_network" "peer" {
  name                    = "tt-peer-${var.suffix}"
  auto_create_subnetworks = false
}

module "vpn" {
  source       = "../../../modules/hybrid-connectivity"
  project_id   = var.project_id
  region       = var.region
  name         = "tt-vpn-${var.suffix}"
  peer_name    = "tt-peer-${var.suffix}"
  network      = google_compute_network.local.id
  peer_network = google_compute_network.peer.id
  labels       = local.labels
}

output "tunnel_self_links" {
  value = module.vpn.tunnel_self_links
}

output "peer_tunnel_self_links" {
  value = module.vpn.peer_tunnel_self_links
}
