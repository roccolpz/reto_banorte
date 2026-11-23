# Fixture de Terratest para modules/cloud-sql: lo aplica y destruye una prueba de test/integration/modules_test.go
# en un proyecto efímero. No es una raíz de etapa: CI solo lo valida (job terratest-compile).
terraform {
  required_version = ">= 1.9"
  required_providers {
    google      = { source = "hashicorp/google", version = ">= 6.0, < 7.0" }
    google-beta = { source = "hashicorp/google-beta", version = ">= 6.0, < 7.0" }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
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

module "network" {
  source     = "../_network"
  project_id = var.project_id
  name       = "tt-sql-${var.suffix}"
  region     = var.region
  psa        = true
}

# Agente de servicio de Cloud SQL: necesita la llave CMEK antes de crear la instancia.
resource "google_project_service_identity" "sql" {
  provider = google-beta
  project  = var.project_id
  service  = "sqladmin.googleapis.com"
}

module "kms" {
  source       = "../../../modules/kms"
  project_id   = var.project_id
  location     = var.region
  keyring_name = "tt-sql-${var.suffix}"
  keys = {
    sql = { encrypter_decrypters = ["serviceAccount:${google_project_service_identity.sql.email}"] }
  }
  labels = local.labels
}

module "cloud_sql" {
  source       = "../../../modules/cloud-sql"
  name         = "tt-sql-${var.suffix}"
  project_id   = var.project_id
  region       = var.region
  network      = module.network.network_id
  kms_key_name = module.kms.key_ids["sql"]
  labels       = local.labels

  # La llave y su IAM deben existir antes que la instancia.
  depends_on = [module.kms]
}

output "instance_name" {
  value = module.cloud_sql.instance_name
}

output "private_ip_address" {
  value = module.cloud_sql.private_ip_address
}

output "psa_cidr" {
  value = module.network.psa_cidr
}
