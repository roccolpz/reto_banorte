locals {
  labels = merge(var.labels, { env = "bootstrap", managed_by = "terraform" })
  envs   = ["dev", "qa", "prod"]

  # Llave de la etapa => cuenta de servicio y prefijo de estado donde puede escribir.
  stage_sas = merge(
    {
      "1-org"          = { account_id = "sa-tf-1-org", prefix = "1-org" }
      "2-security"     = { account_id = "sa-tf-2-sec", prefix = "2-security" }
      "3-networks-hub" = { account_id = "sa-tf-3-net-hub", prefix = "3-networks/hub" }
    },
    { for e in local.envs : "3-networks-${e}" => { account_id = "sa-tf-3-net-${e}", prefix = "3-networks/${e}" } },
    { for e in local.envs : "4-projects-${e}" => { account_id = "sa-tf-4-proj-${e}", prefix = "4-projects/${e}" } },
    { for e in local.envs : "5-workloads-${e}" => { account_id = "sa-tf-5-wl-${e}", prefix = "5-workloads/${e}" } },
  )

  # La SA de plan solo lee: no tiene prefijo de escritura.
  service_accounts = merge({ plan = { account_id = "sa-tf-plan", prefix = null } }, local.stage_sas)

  # Prefijos de estado que cada etapa lee con terraform_remote_state (R4). Agregar aquí el prefijo antes de
  # leer un estado nuevo; la SA de plan lee todo el bucket (ADR 0008-g).
  state_read_prefixes = merge(
    {
      "1-org"          = ["0-bootstrap"]
      "2-security"     = concat(["0-bootstrap", "1-org"], [for e in local.envs : "4-projects/${e}"])
      "3-networks-hub" = ["1-org"]
    },
    { for e in local.envs : "3-networks-${e}" => ["1-org", "3-networks/hub"] },
    { for e in local.envs : "4-projects-${e}" => ["0-bootstrap", "1-org", "2-security", "3-networks/${e}"] },
    { for e in local.envs : "5-workloads-${e}" => ["2-security", "3-networks/hub", "3-networks/${e}", "4-projects/${e}"] },
  )

  # Roles a nivel organización que se necesitan antes de que exista 1-org.
  # Los permisos de las etapas 2 a 5 los otorga 1-org sobre las carpetas y proyectos que crea.
  org_roles = {
    "1-org" = [
      "roles/resourcemanager.organizationAdmin",
      "roles/resourcemanager.folderAdmin",
      "roles/resourcemanager.projectCreator",
      "roles/orgpolicy.policyAdmin",
      "roles/compute.orgFirewallPolicyAdmin",
      "roles/compute.orgSecurityResourceAdmin",
      "roles/logging.configWriter",
      # Notificaciones de SCC y roles a medida (kms_key_iam_admin, tag_value_iam_admin) que crea 1-org.
      "roles/securitycenter.notificationConfigEditor",
      "roles/iam.organizationRoleAdmin",
    ]
    plan = [
      "roles/viewer",
      "roles/iam.securityReviewer",
      "roles/orgpolicy.policyViewer",
      "roles/resourcemanager.folderViewer",
      "roles/accesscontextmanager.policyReader",
      "roles/securitycenter.notificationConfigViewer",
    ]
  }
  org_bindings = {
    for b in flatten([for sa, roles in local.org_roles : [for r in roles : { sa = sa, role = r }]]) :
    "${b.sa}|${b.role}" => b
  }

  # SA que crean proyectos y por eso necesitan ligar la cuenta de facturación.
  billing_users = concat(["1-org"], [for e in local.envs : "4-projects-${e}"])

  wif_principal_repo = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repository}"
  prod_gated_common  = ["1-org", "2-security", "3-networks-hub"]
  wif_principal_prod = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.environment/prod"

  # Las etapas >= 1 usan la semilla como billing_project (user_project_override),
  # así que aquí van las APIs que llaman a nivel organización.
  seed_apis = [
    "accesscontextmanager.googleapis.com",
    "cloudbilling.googleapis.com",
    "cloudkms.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "logging.googleapis.com",
    # Las etapas facturan sus llamadas a la semilla (user_project_override): 5-workloads usa Cloud SQL y Monitoring.
    "monitoring.googleapis.com",
    "orgpolicy.googleapis.com",
    "pubsub.googleapis.com",
    "securitycenter.googleapis.com",
    "serviceusage.googleapis.com",
    "sqladmin.googleapis.com",
    "storage.googleapis.com",
    "sts.googleapis.com",
  ]
}

# ---------------------------------------------------------------------------
# Carpeta y proyecto semilla
# ---------------------------------------------------------------------------

resource "google_folder" "bootstrap" {
  display_name = "bootstrap"
  parent       = "organizations/${var.org_id}"
}

module "seed_project" {
  source = "../../modules/project-factory"

  name            = "${var.prefix} bootstrap seed"
  project_id      = "${var.prefix}-bootstrap-seed-${var.suffix}"
  folder_id       = google_folder.bootstrap.name
  billing_account = var.billing_account
  labels          = local.labels
  # El proyecto semilla guarda el estado de todas las etapas: no se borra con destroy.
  deletion_policy = "PREVENT"

  activate_apis = local.seed_apis
}

# ---------------------------------------------------------------------------
# Cifrado del estado (CMEK, rotación de 90 días)
# ---------------------------------------------------------------------------

resource "google_kms_key_ring" "state" {
  project  = module.seed_project.project_id
  name     = "${var.prefix}-bootstrap-state-kr-${var.suffix}"
  location = var.region
}

resource "google_kms_crypto_key" "state" {
  name            = "${var.prefix}-bootstrap-state-key"
  key_ring        = google_kms_key_ring.state.id
  rotation_period = "7776000s"
  labels          = local.labels
}

data "google_storage_project_service_account" "gcs" {
  project = module.seed_project.project_id

  depends_on = [module.seed_project]
}

resource "google_kms_crypto_key_iam_member" "gcs_state" {
  crypto_key_id = google_kms_crypto_key.state.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${data.google_storage_project_service_account.gcs.email_address}"
}

# ---------------------------------------------------------------------------
# Bucket de estado
# ---------------------------------------------------------------------------

resource "google_storage_bucket" "state" {
  project                     = module.seed_project.project_id
  name                        = "${var.prefix}-bootstrap-tfstate-${var.suffix}"
  location                    = var.region
  force_destroy               = false
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  labels                      = local.labels

  versioning {
    enabled = true
  }

  encryption {
    default_kms_key_name = google_kms_crypto_key.state.id
  }

  depends_on = [google_kms_crypto_key_iam_member.gcs_state]
}

# ---------------------------------------------------------------------------
# Cuentas de servicio por etapa
# ---------------------------------------------------------------------------

resource "google_service_account" "stage" {
  for_each = local.service_accounts

  project      = module.seed_project.project_id
  account_id   = each.value.account_id
  display_name = "Terraform ${each.key}"
}

# Cada etapa lista el bucket (backend gcs) y lee solo los prefijos que consume (R4); plan lee todo (ADR 0008-g).
resource "google_storage_bucket_iam_member" "state_reader" {
  for_each = local.service_accounts

  bucket = google_storage_bucket.state.name
  role   = "roles/storage.objectViewer"
  member = google_service_account.stage[each.key].member

  dynamic "condition" {
    for_each = each.key == "plan" ? [] : [local.state_read_prefixes[each.key]]
    content {
      title       = "lee-${each.key}"
      description = "Listar el bucket y leer ${join(", ", condition.value)}"
      expression = join(" || ", concat(
        ["resource.type == \"storage.googleapis.com/Bucket\""],
        [for prefix in condition.value : "resource.name.startsWith(\"projects/_/buckets/${google_storage_bucket.state.name}/objects/${prefix}/\")"],
      ))
    }
  }
}

# Cada SA de etapa escribe (estado y lock) solo bajo su prefijo.
resource "google_storage_bucket_iam_member" "stage_writer" {
  for_each = local.stage_sas

  bucket = google_storage_bucket.state.name
  role   = "roles/storage.objectAdmin"
  member = google_service_account.stage[each.key].member

  condition {
    title       = "solo-prefijo-${each.key}"
    description = "Escritura limitada al prefijo ${each.value.prefix}/"
    expression  = "resource.name.startsWith(\"projects/_/buckets/${google_storage_bucket.state.name}/objects/${each.value.prefix}/\")"
  }
}

# Las etapas >= 1 facturan las llamadas a nivel organización al proyecto semilla.
resource "google_project_iam_member" "seed_usage" {
  for_each = local.service_accounts

  project = module.seed_project.project_id
  role    = "roles/serviceusage.serviceUsageConsumer"
  member  = google_service_account.stage[each.key].member
}

resource "google_organization_iam_member" "stage" {
  for_each = local.org_bindings

  org_id = var.org_id
  role   = each.value.role
  member = google_service_account.stage[each.value.sa].member
}

resource "google_billing_account_iam_member" "project_creators" {
  for_each = toset(local.billing_users)

  billing_account_id = var.billing_account
  role               = "roles/billing.user"
  member             = google_service_account.stage[each.key].member
}

# ---------------------------------------------------------------------------
# Workload Identity Federation para GitHub Actions
# ---------------------------------------------------------------------------

resource "google_iam_workload_identity_pool" "github" {
  project                   = module.seed_project.project_id
  workload_identity_pool_id = "${var.prefix}-github-pool"
  display_name              = "GitHub Actions"
  description               = "Identidades de GitHub Actions del repositorio ${var.github_repository}"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = module.seed_project.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub OIDC"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
    "attribute.actor"      = "assertion.actor"
    # El claim environment solo existe en jobs con environment de GitHub.
    "attribute.environment" = "has(assertion.environment) ? assertion.environment : \"none\""
  }

  attribute_condition = "assertion.repository == \"${var.github_repository}\""

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# Las SA *-prod y las de etapas comunes (1-org, 2-security, 3-networks-hub) solo se impersonan desde el environment
# prod de GitHub: tocan recursos de los que depende prod. El resto, incluida la SA de plan, desde cualquier job del
# repositorio autorizado (attribute_condition del proveedor).
resource "google_service_account_iam_member" "wif" {
  for_each = local.service_accounts

  service_account_id = google_service_account.stage[each.key].name
  role               = "roles/iam.workloadIdentityUser"
  member             = endswith(each.key, "-prod") || contains(local.prod_gated_common, each.key) ? local.wif_principal_prod : local.wif_principal_repo
}
