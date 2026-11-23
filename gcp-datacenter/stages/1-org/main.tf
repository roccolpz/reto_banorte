data "terraform_remote_state" "bootstrap" {
  backend = "gcs"
  config = {
    bucket = var.state_bucket
    prefix = "0-bootstrap"
  }
}

locals {
  envs   = ["dev", "qa", "prod"]
  org    = "organizations/${var.org_id}"
  labels = merge(var.labels, { managed_by = "terraform" })

  common_projects = {
    net_hub = {
      domain = "net-hub"
      apis   = ["compute.googleapis.com", "dns.googleapis.com", "networkconnectivity.googleapis.com", "logging.googleapis.com"]
    }
    logging = {
      domain = "logging"
      apis   = ["logging.googleapis.com", "storage.googleapis.com", "monitoring.googleapis.com"]
    }
    security = {
      domain = "security"
      apis   = ["cloudkms.googleapis.com", "secretmanager.googleapis.com", "accesscontextmanager.googleapis.com", "securitycenter.googleapis.com", "pubsub.googleapis.com", "logging.googleapis.com"]
    }
    backup = {
      domain = "backup"
      apis   = ["storage.googleapis.com", "logging.googleapis.com"]
    }
  }

  net_host_apis = [
    "compute.googleapis.com",
    "container.googleapis.com",
    "dns.googleapis.com",
    "networkconnectivity.googleapis.com",
    "servicenetworking.googleapis.com",
    "logging.googleapis.com",
    # Tags seguros GCE_FIREWALL que 3-networks crea en el net-host.
    "cloudresourcemanager.googleapis.com",
  ]

  # compact_projects: un solo proyecto common y un proyecto por entorno que también aloja app y datos
  # (lo que en el diseño completo crea 4-projects). Para organizaciones de prueba con poca cuota de facturación.
  env_workload_apis = [
    "container.googleapis.com",
    "binaryauthorization.googleapis.com",
    "iam.googleapis.com",
    "monitoring.googleapis.com",
    "sqladmin.googleapis.com",
    "storage.googleapis.com",
  ]

  common_project_defs = var.compact_projects ? {
    common = { domain = "common", apis = distinct(flatten([for c in values(local.common_projects) : c.apis])) }
  } : local.common_projects

  # Siempre con las cuatro llaves (net_hub, logging, security, backup); en modo compacto apuntan al mismo proyecto.
  common_project_ids     = { for k in keys(local.common_projects) : k => module.common_project[var.compact_projects ? "common" : k].project_id }
  common_project_numbers = { for k in keys(local.common_projects) : k => module.common_project[var.compact_projects ? "common" : k].project_number }
}

# ---------------------------------------------------------------------------
# Carpetas (bootstrap la crea 0-bootstrap)
# ---------------------------------------------------------------------------

resource "google_folder" "this" {
  for_each = toset(concat(["common"], local.envs))

  display_name = each.key
  parent       = local.org
}

# ---------------------------------------------------------------------------
# Proyectos de common y proyectos host de red por entorno
# ---------------------------------------------------------------------------

module "common_project" {
  source   = "../../modules/project-factory"
  for_each = local.common_project_defs

  name            = var.compact_projects ? "${var.prefix} common" : "${var.prefix} common ${each.value.domain}"
  project_id      = var.compact_projects ? "${var.prefix}-common-${var.suffix}" : "${var.prefix}-common-${each.value.domain}-${var.suffix}"
  folder_id       = google_folder.this["common"].name
  billing_account = var.billing_account
  activate_apis   = each.value.apis
  labels          = merge(local.labels, { env = "common" })
}

# Se habilitan como host de Shared VPC en 3-networks, no aquí.
module "net_host_project" {
  source   = "../../modules/project-factory"
  for_each = toset(local.envs)

  name            = var.compact_projects ? "${var.prefix} ${each.key}" : "${var.prefix} ${each.key} net-host"
  project_id      = var.compact_projects ? "${var.prefix}-${each.key}-${var.suffix}" : "${var.prefix}-${each.key}-net-host-${var.suffix}"
  folder_id       = google_folder.this[each.key].name
  billing_account = var.billing_account
  activate_apis   = var.compact_projects ? distinct(concat(local.net_host_apis, local.env_workload_apis)) : local.net_host_apis
  labels          = merge(local.labels, { env = each.key })
}
