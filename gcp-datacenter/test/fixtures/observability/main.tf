# Fixture de Terratest para modules/observability: lo aplica y destruye una prueba de test/integration/modules_test.go
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

variable "notification_email" {
  description = "Correo del canal de alertas de la prueba."
  type        = string
  default     = "noc@example.com"
}

module "observability" {
  source             = "../../../modules/observability"
  project_id         = var.project_id
  name_prefix        = "tt-${var.suffix}"
  notification_email = var.notification_email
  labels             = local.labels
}

output "notification_channel_id" {
  value = module.observability.notification_channel_id
}

output "alert_policy_ids" {
  value = module.observability.alert_policy_ids
}
