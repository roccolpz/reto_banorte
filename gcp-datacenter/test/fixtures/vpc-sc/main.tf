# Fixture de Terratest para modules/vpc-sc: lo aplica y destruye una prueba de test/integration/modules_test.go
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

variable "access_policy_name" {
  description = "Número de la política de Access Context Manager de pruebas (TEST_ACCESS_POLICY)."
  type        = string
}

data "google_project" "this" {
  project_id = var.project_id
}

# Solo dry-run: la prueba no debe bloquear servicios del proyecto efímero.
module "perimeter" {
  source              = "../../../modules/vpc-sc"
  perimeter_name      = "tt_${var.suffix}"
  access_policy_name  = var.access_policy_name
  enforce             = false
  restricted_services = ["storage.googleapis.com"]
  member_projects     = [data.google_project.this.number]
}

output "name" {
  value = module.perimeter.name
}

output "enforced" {
  value = module.perimeter.enforced
}
