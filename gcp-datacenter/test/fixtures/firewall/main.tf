# Fixture de Terratest para modules/firewall: lo aplica y destruye una prueba de test/integration/modules_test.go
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

module "network" {
  source     = "../_network"
  project_id = var.project_id
  name       = "tt-fw-${var.suffix}"
  region     = var.region
}

module "firewall" {
  source      = "../../../modules/firewall"
  project_id  = var.project_id
  network     = module.network.network_self_link
  name_prefix = "tt-fw-${var.suffix}"
  secure_tags = ["gke-nodes", "vm"]

  # Mismo patrón que 3-networks/envs: on-prem solo a 80/443 de las cargas etiquetadas, el resto se niega.
  rules = {
    allow-onprem-web = {
      priority       = 1000
      ranges         = ["192.168.0.0/16"]
      protocols      = [{ protocol = "tcp", ports = ["80", "443"] }]
      target_tags    = ["gke-nodes", "vm"]
      enable_logging = true
    }
    deny-all-ingress = {
      action   = "deny"
      priority = 65000
      ranges   = ["0.0.0.0/0"]
    }
  }
}

output "rule_names" {
  value = module.firewall.rule_names
}

output "secure_tag_values" {
  value = module.firewall.secure_tag_values
}
