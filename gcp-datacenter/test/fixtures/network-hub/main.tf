# Fixture de Terratest para modules/network-hub: lo aplica y destruye una prueba de test/integration/modules_test.go
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

module "hub" {
  source                = "../../../modules/network-hub"
  project_id            = var.project_id
  prefix                = "tt${var.suffix}"
  onprem_dns_target_ips = ["192.168.10.2"]
  labels                = local.labels
}

output "network_name" {
  value = module.hub.network_name
}

output "ncc_hub_id" {
  value = module.hub.ncc_hub_id
}
