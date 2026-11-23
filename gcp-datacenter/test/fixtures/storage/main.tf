# Fixture de Terratest para modules/storage: lo aplica y destruye una prueba de test/integration/modules_test.go
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

# Agente de servicio de Cloud Storage: cifra el bucket con la llave CMEK.
data "google_storage_project_service_account" "gcs" {
  project = var.project_id
}

module "kms" {
  source       = "../../../modules/kms"
  project_id   = var.project_id
  location     = var.region
  keyring_name = "tt-gcs-${var.suffix}"
  keys = {
    storage = { encrypter_decrypters = ["serviceAccount:${data.google_storage_project_service_account.gcs.email_address}"] }
  }
  labels = local.labels
}

module "storage" {
  source       = "../../../modules/storage"
  name         = "${var.project_id}-tt-${var.suffix}"
  project_id   = var.project_id
  location     = upper(var.region)
  kms_key_name = module.kms.key_ids["storage"]
  labels       = local.labels

  # Solo en pruebas: el destroy borra los objetos.
  force_destroy = true

  depends_on = [module.kms]
}

output "bucket_name" {
  value = module.storage.bucket_name
}
