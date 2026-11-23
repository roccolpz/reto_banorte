# Fixture de Terratest para modules/project-factory: lo aplica y destruye una prueba de test/integration/modules_test.go
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

variable "folder_id" {
  description = "Folder de pruebas donde se crea el proyecto (TEST_FOLDER_ID, folders/<n>)."
  type        = string
}

variable "billing_account" {
  description = "Cuenta de facturación de pruebas (TEST_BILLING_ACCOUNT)."
  type        = string
}

module "project" {
  source          = "../../../modules/project-factory"
  name            = "tt pf ${var.suffix}"
  project_id      = "tt-pf-${var.suffix}"
  folder_id       = var.folder_id
  billing_account = var.billing_account
  activate_apis   = ["compute.googleapis.com"]
  labels          = local.labels

  # La prueba borra el proyecto al terminar.
  deletion_policy = "DELETE"
}

output "project_id" {
  value = module.project.project_id
}
