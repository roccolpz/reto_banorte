# Binary Authorization (ADR 0022-k). Solo prod recibe binauthz_attestor: su proyecto de app exige la atestación
# qa-approved (imágenes aprobadas por dos usuarios de QA y firmadas por el pipeline). dev y qa quedan con la política
# por defecto del proyecto (admite todo), que el clúster ya evalúa con PROJECT_SINGLETON_POLICY_ENFORCE.

locals {
  binauthz_enabled = var.binauthz_attestor != null
  binauthz_agent   = "serviceAccount:service-${local.app_number}@gcp-sa-binaryauthorization.iam.gserviceaccount.com"
}

# El agente de Binary Authorization del proyecto de app verifica las atestaciones contra el attestor del proyecto de
# seguridad. 4-projects-prod puede dar este binding por el rol a medida attestor_iam_admin (2-security).
resource "google_binary_authorization_attestor_iam_member" "verifier" {
  count = local.binauthz_enabled ? 1 : 0

  project  = var.binauthz_attestor.project
  attestor = var.binauthz_attestor.name
  role     = "roles/binaryauthorization.attestorsVerifier"
  member   = local.binauthz_agent

  depends_on = [module.app]
}

resource "google_binary_authorization_policy" "this" {
  count = local.binauthz_enabled ? 1 : 0

  project     = local.app_project_id
  description = "${var.env}: solo imágenes con la atestación qa-approved (2 aprobaciones de QA, ADR 0021-k y 0022-k)."

  # Imágenes de sistema de GKE (kube-system, agentes de Google) se admiten sin atestación.
  global_policy_evaluation_mode = "ENABLE"

  default_admission_rule {
    evaluation_mode         = "REQUIRE_ATTESTATION"
    enforcement_mode        = "ENFORCED_BLOCK_AND_AUDIT_LOG"
    require_attestations_by = [var.binauthz_attestor.id]
  }

  depends_on = [module.app, google_binary_authorization_attestor_iam_member.verifier]
}
