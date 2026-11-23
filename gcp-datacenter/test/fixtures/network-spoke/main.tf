# Fixture de Terratest para modules/network-spoke: lo aplica y destruye una prueba de test/integration/modules_test.go
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
    cost_center = "TI-001"
    managed_by  = "terraform"
  }
}

module "spoke" {
  source     = "../../../modules/network-spoke"
  project_id = var.project_id
  prefix     = "tt${var.suffix}"
  env        = "dev"
  psa_cidr   = "10.10.128.0/20"
  labels     = local.labels

  # El proyecto efímero no es host de Shared VPC: evita pedir permisos de organización.
  enable_shared_vpc_host = false

  regions = {
    (var.region) = {
      app_cidr      = "10.10.0.0/20"
      services_cidr = "10.10.32.0/22"
      proxy_cidr    = "10.10.48.0/23"
      pods_cidr     = "10.10.64.0/18"
    }
  }
}

output "network_name" {
  value = module.spoke.network_name
}

output "subnets" {
  value = module.spoke.subnets
}
