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

# 4-projects-<env> concede cryptoKeyEncrypterDecrypter a los agentes de sus proyectos. El rol a medida
# kms_key_iam_admin de 1-org solo trae cryptoKeys.get/getIamPolicy/setIamPolicy (sin destruir versiones, P8);
# se otorga por keyring del entorno, no en el proyecto, para que dev no toque prod.
resource "google_kms_key_ring_iam_member" "stage_4_projects" {
  for_each = local.keyrings

  key_ring_id = module.kms[each.key].keyring_id
  role        = data.terraform_remote_state.org.outputs.custom_role_ids["kms_key_iam_admin"]
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

# Solo las SAs de carga del entorno leen sus secretos (Fase 3: "únicamente a esas identidades autorizadas").
resource "google_secret_manager_secret_iam_member" "accessors" {
  for_each = merge([
    for k, secret in google_secret_manager_secret.secrets : {
      for sa_key in ["app_workload", "vm"] : "${k}/${sa_key}" => {
        secret = k
        member = "serviceAccount:${local.workload_sas[split("/", k)[0]][sa_key]}"
      } if contains(keys(local.workload_sas[split("/", k)[0]]), sa_key)
    }
  ]...)

  project   = local.security_project_id
  secret_id = google_secret_manager_secret.secrets[each.value.secret].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = each.value.member
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
  enforce             = var.vpc_sc_enforce[each.key]
  restricted_services = var.restricted_services
  ingress_identities  = local.ingress_identities[each.key]
  egress_rules        = local.egress_rules[each.key]
}

# --- Estado de 4-projects: proyectos de dev y qa e identidades de carga de los tres entornos ---
# La política de acceso no tiene IAM por perímetro: si las SAs de 4-projects-dev/qa tuvieran policyEditor
# podrían editar el perímetro de prod. 2-security (con aprobación) agrega sus proyectos de app y datos;
# prod los agrega 4-projects-prod (ADR 0007-f). El estado de 4-projects/<env> no existe en la primera corrida:
# se lista el prefijo antes de leerlo, y la siguiente corrida de 2-security recoge proyectos, accesores de
# secretos y egreso (ADR 0013-g).
locals {
  delegated_envs = ["dev", "qa"]
}

data "google_storage_bucket_objects" "projects_state" {
  for_each = toset(local.envs)

  bucket = var.state_bucket
  prefix = "4-projects/${each.key}/"
}

data "terraform_remote_state" "projects" {
  for_each = toset([for e in local.envs : e if length(data.google_storage_bucket_objects.projects_state[e].bucket_objects) > 0])

  backend = "gcs"
  config  = { bucket = var.state_bucket, prefix = "4-projects/${each.key}" }
}

locals {
  env_perimeter_projects = merge([
    for e, s in data.terraform_remote_state.projects : {
      for d in ["app", "data"] : "${e}/${d}" => { env = e, resource = "projects/${s.outputs["${d}_project_number"]}" }
      if contains(local.delegated_envs, e) && try(s.outputs["${d}_project_number"], null) != null
    }
  ]...)

  # SAs de carga (app_workload, vm, gke_nodes) por entorno; vacío hasta que 4-projects/<env> exista.
  workload_sas = { for e in local.envs : e => try(data.terraform_remote_state.projects[e].outputs.service_accounts, {}) }

  # Egreso explícito (Fase 3 §5.3): app_workload escribe respaldos en el bucket del proyecto común de respaldo,
  # fuera del perímetro. Nada más sale (ADR 0013-g).
  backup_project_number = try(data.terraform_remote_state.org.outputs.common_project_numbers["backup"], null)
  egress_rules = {
    for e in local.envs : e => [
      for sa in compact([try(local.workload_sas[e]["app_workload"], "")]) : {
        identities = ["serviceAccount:${sa}"]
        resources  = ["projects/${local.backup_project_number}"]
        services   = ["storage.googleapis.com"]
      } if local.backup_project_number != null
    ]
  }
}

resource "google_access_context_manager_service_perimeter_dry_run_resource" "env_projects" {
  for_each = { for k, v in local.env_perimeter_projects : k => v if !var.vpc_sc_enforce[v.env] }

  perimeter_name = module.perimeter[each.value.env].name
  resource       = each.value.resource
}

resource "google_access_context_manager_service_perimeter_resource" "env_projects" {
  for_each = { for k, v in local.env_perimeter_projects : k => v if var.vpc_sc_enforce[v.env] }

  perimeter_name = module.perimeter[each.value.env].name
  resource       = each.value.resource
}
