# Fixture de Terratest para modules/compute-mig: lo aplica y destruye una prueba de test/integration/modules_test.go
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
  name       = "tt-mig-${var.suffix}"
  region     = var.region
}

resource "google_service_account" "vm" {
  account_id   = "tt-mig-${var.suffix}"
  display_name = "Terratest compute-mig"
}

module "mig" {
  source                = "../../../modules/compute-mig"
  name                  = "tt-mig-${var.suffix}"
  project_id            = var.project_id
  region                = var.region
  subnetwork            = module.network.subnetwork_id
  service_account_email = google_service_account.vm.email
  labels                = local.labels
}

output "mig_name" {
  value = module.mig.mig_name
}
