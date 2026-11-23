# Fixture de Terratest para modules/gke: lo aplica y destruye una prueba de test/integration/modules_test.go
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

module "network" {
  source     = "../_network"
  project_id = var.project_id
  name       = "tt-gke-${var.suffix}"
  region     = var.region
}

resource "google_service_account" "nodes" {
  account_id   = "tt-gke-${var.suffix}"
  display_name = "Terratest gke (nodos)"
}

module "gke" {
  source                 = "../../../modules/gke"
  cluster_name           = "tt-gke-${var.suffix}"
  project_id             = var.project_id
  region                 = var.region
  network                = module.network.network_id
  subnetwork             = module.network.subnetwork_id
  pods_range_name        = "pods"
  services_range_name    = "services"
  master_ipv4_cidr_block = "172.16.10.0/28"
  node_service_account   = google_service_account.nodes.email
  labels                 = local.labels

  node_pools = {
    general = { machine_type = "e2-standard-2", min_count = 1, max_count = 1 }
  }
}

output "cluster_name" {
  value = module.gke.cluster_name
}

output "workload_pool" {
  value = module.gke.workload_pool
}
