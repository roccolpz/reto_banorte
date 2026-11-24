# ==========================================================
# Separación de funciones: "quién aprueba" vs "quién despliega"
#
# - El deployer (cuenta de servicio) es la ÚNICA identidad con
#   permisos de escritura sobre el entorno. Ninguna persona
#   recibe permiso para usarla aquí: eso lo hará el pipeline
#   (Workload Identity Federation) en el punto B.
# - Los aprobadores de QA (Google Group) solo pueden VER el
#   entorno. Su aprobación ocurre en el pipeline / GitHub,
#   no en GCP.
# ==========================================================

locals {
  deployer_member = "serviceAccount:${google_service_account.deployer.email}"
}

# ---------------- QUIÉN DESPLIEGA ----------------

resource "google_service_account" "deployer" {
  project      = var.project_id
  account_id   = var.deployer_account_id
  display_name = "Terraform deployer (${var.environment})"
  description  = "Única identidad con escritura en ${var.environment}. Solo la usa el pipeline tras la aprobación de QA."
}

resource "google_project_iam_member" "deployer" {
  for_each = toset(var.deployer_project_roles)
  project  = var.project_id
  role     = each.value
  member   = local.deployer_member
}

# Los node pools corren con la cuenta de servicio por defecto de Compute.
# Para crearlos, el deployer debe poder "actuar como" ESA cuenta,
# así que el permiso se da sobre esa cuenta y no sobre todo el proyecto.
resource "google_service_account_iam_member" "deployer_acts_as_node_sa" {
  service_account_id = "projects/${var.project_id}/serviceAccounts/${var.project_number}-compute@developer.gserviceaccount.com"
  role               = "roles/iam.serviceAccountUser"
  member             = local.deployer_member
}

# Shared VPC host: el permiso solo existe a nivel carpeta/organización.
# Se limita a la carpeta del entorno, no a toda la organización.
resource "google_folder_iam_member" "deployer_xpn_admin" {
  count  = var.shared_vpc_folder_id != "" ? 1 : 0
  folder = var.shared_vpc_folder_id
  role   = "roles/compute.xpnAdmin"
  member = local.deployer_member
}

# Perímetros VPC-SC: permiso sobre la Access Policy, no sobre la organización.
resource "google_access_context_manager_access_policy_iam_member" "deployer" {
  count  = var.grant_access_policy_editor ? 1 : 0
  name   = var.access_policy_name
  role   = "roles/accesscontextmanager.policyEditor"
  member = local.deployer_member
}

# ---------------- QUIÉN APRUEBA ----------------

resource "google_project_iam_member" "approvers_read_only" {
  for_each = toset(var.approver_project_roles)
  project  = var.project_id
  role     = each.value
  member   = "group:${var.approvers_group}"
}
