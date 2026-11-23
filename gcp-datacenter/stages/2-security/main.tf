data "terraform_remote_state" "bootstrap" {
  backend = "gcs"
  config  = { bucket = var.state_bucket, prefix = "0-bootstrap" }
}

data "terraform_remote_state" "org" {
  backend = "gcs"
  config  = { bucket = var.state_bucket, prefix = "1-org" }
}

locals {
  envs                = ["dev", "qa", "prod"]
  security_project_id = data.terraform_remote_state.org.outputs.common_project_ids["security"]
  stage_sas           = data.terraform_remote_state.bootstrap.outputs.stage_service_accounts
  labels              = merge(var.labels, { managed_by = "terraform" })

  # Un keyring por entorno en us-central1; prod suma un keyring DR en us-east4 para la réplica de Cloud SQL
  # y uno en la multi-región us para el bucket dual-region (ADR 0002-d).
  keyrings = {
    dev     = { env = "dev", location = "us-central1", keys = ["storage", "sql", "gke"] }
    qa      = { env = "qa", location = "us-central1", keys = ["storage", "sql", "gke"] }
    prod    = { env = "prod", location = "us-central1", keys = ["storage", "sql", "gke"] }
    prod-dr = { env = "prod", location = "us-east4", keys = ["sql-dr"] }
    prod-us = { env = "prod", location = "us", keys = ["storage-us"] }
  }

  access_policy_name = var.create_access_policy ? google_access_context_manager_access_policy.this[0].name : var.access_policy_name

  # Ingreso solo para la SA de plan y las SA de etapa del mismo entorno (p. ej. 4-projects-dev, 5-workloads-dev).
  ingress_identities = {
    for env in local.envs : env => [
      for k, sa in local.stage_sas : "serviceAccount:${sa}" if k == "plan" || endswith(k, "-${env}")
    ]
  }
}

# --- Cloud KMS (CMEK, rotación de 90 días) ---
# Los permisos de cifrado para los agentes de servicio los otorga 4-projects, cuando existen los proyectos de app y datos.
module "kms" {
  for_each = local.keyrings
  source   = "../../modules/kms"

  project_id   = local.security_project_id
  location     = each.value.location
  keyring_name = "${var.prefix}-${each.key}-keyring-${var.suffix}"
  keys         = { for k in each.value.keys : k => {} }
  labels       = merge(local.labels, { env = each.value.env })
}

# 4-projects-<env> concede cryptoKeyEncrypterDecrypter a los agentes de sus proyectos. cloudkms.admin es el único rol
# predefinido con cryptoKeys.setIamPolicy; se otorga por keyring del entorno, no en el proyecto, para que dev no toque prod.
resource "google_kms_key_ring_iam_member" "stage_4_projects" {
  for_each = local.keyrings

  key_ring_id = module.kms[each.key].keyring_id
  role        = "roles/cloudkms.admin"
  member      = "serviceAccount:${local.stage_sas["4-projects-${each.value.env}"]}"
}

# --- Secret Manager: solo contenedores; los valores se cargan fuera de Terraform ---
resource "google_secret_manager_secret" "secrets" {
  for_each = { for p in setproduct(local.envs, var.secret_names) : "${p[0]}/${p[1]}" => { env = p[0], name = p[1] } }

  project             = local.security_project_id
  secret_id           = "${var.prefix}-${each.value.env}-${each.value.name}"
  labels              = merge(local.labels, { env = each.value.env })
  deletion_protection = each.value.env == "prod"

  replication {
    user_managed {
      replicas {
        location = "us-central1"
      }
      replicas {
        location = "us-east4"
      }
    }
  }
}

# --- VPC Service Controls ---
# Una organización admite una sola política de acceso; por default se usa la existente.
resource "google_access_context_manager_access_policy" "this" {
  count = var.create_access_policy ? 1 : 0

  parent = "organizations/${var.org_id}"
  title  = "${var.prefix}-access-policy"
}

module "perimeter" {
  for_each = toset(local.envs)
  source   = "../../modules/vpc-sc"

  perimeter_name      = "${var.prefix}_${each.key}_perimeter"
  access_policy_name  = local.access_policy_name
  enforce             = var.vpc_sc_enforce
  restricted_services = var.restricted_services
  ingress_identities  = local.ingress_identities[each.key]
}
