# Binary Authorization de prod (ADR 0022-k): attestor "qa-approved" en el proyecto de seguridad.
#
# Flujo: un PR agrega imágenes (por digest) a gcp-datacenter/release/prod-images.txt → la puerta qa-approval exige
# 2 aprobaciones de QA (ADR 0021-k) → el job attest-prod de apply.yml, con la SA attestor-prod, firma cada imagen
# con esta llave → la política del proyecto de app de prod (4-projects-prod) solo admite imágenes firmadas aquí.
#
# Nadie más firma: attestor-prod es la única identidad con signerVerifier, y solo sobre esta llave.

locals {
  attestor_sa = local.stage_sas["attestor-prod"]
}

# Llave asimétrica de firma en el keyring de prod. Las llaves asimétricas no rotan solas: para rotar, crear una
# versión nueva, agregar su llave pública al attestor y luego deshabilitar la anterior.
resource "google_kms_crypto_key" "binauthz_qa" {
  name     = "binauthz-qa-approved"
  key_ring = module.kms["prod"].keyring_id
  purpose  = "ASYMMETRIC_SIGN"
  labels   = merge(local.labels, { env = "prod" })

  version_template {
    algorithm        = "EC_SIGN_P256_SHA256"
    protection_level = "SOFTWARE"
  }
}

# Leer la llave pública (para el attestor) pide cloudkms.cryptoKeyVersions.viewPublicKey, que no trae el rol de
# administración de KMS. Solo sobre esta llave: la SA de 2-security (apply) y la de plan (PR y drift).
resource "google_kms_crypto_key_iam_member" "binauthz_pubkey_viewer" {
  for_each = toset(["2-security", "plan"])

  crypto_key_id = google_kms_crypto_key.binauthz_qa.id
  role          = "roles/cloudkms.publicKeyViewer"
  member        = "serviceAccount:${local.stage_sas[each.key]}"
}

data "google_kms_crypto_key_version" "binauthz_qa" {
  crypto_key = google_kms_crypto_key.binauthz_qa.id
  version    = 1

  depends_on = [google_kms_crypto_key_iam_member.binauthz_pubkey_viewer]
}

resource "google_kms_crypto_key_iam_member" "binauthz_signer" {
  crypto_key_id = google_kms_crypto_key.binauthz_qa.id
  role          = "roles/cloudkms.signerVerifier"
  member        = "serviceAccount:${local.attestor_sa}"
}

resource "google_container_analysis_note" "qa_approved" {
  project = local.security_project_id
  name    = "${var.prefix}-prod-qa-approved"

  attestation_authority {
    hint {
      human_readable_name = "QA aprobó el pase a prod (2 aprobaciones, ADR 0021-k)"
    }
  }
}

resource "google_binary_authorization_attestor" "qa_approved" {
  project     = local.security_project_id
  name        = "${var.prefix}-prod-qa-approved"
  description = "Imágenes de prod aprobadas por dos usuarios de QA; firma solo el pipeline (ADR 0022-k)."

  attestation_authority_note {
    note_reference = google_container_analysis_note.qa_approved.name

    public_keys {
      # Mismo ID que arma scripts/attest-images.sh para --public-key-id.
      id = "//cloudkms.googleapis.com/v1/${google_kms_crypto_key.binauthz_qa.id}/cryptoKeyVersions/1"
      pkix_public_key {
        public_key_pem      = data.google_kms_crypto_key_version.binauthz_qa.public_key[0].pem
        signature_algorithm = data.google_kms_crypto_key_version.binauthz_qa.public_key[0].algorithm
      }
    }
  }
}

# 4-projects-prod da attestorsVerifier al agente de Binary Authorization de su proyecto de app. Rol a medida: solo
# IAM del attestor, sin crearlo, borrarlo ni cambiar su llave.
resource "google_binary_authorization_attestor_iam_member" "stage_4_projects_prod" {
  project  = local.security_project_id
  attestor = google_binary_authorization_attestor.qa_approved.name
  role     = data.terraform_remote_state.org.outputs.custom_role_ids["attestor_iam_admin"]
  member   = "serviceAccount:${local.stage_sas["4-projects-prod"]}"
}

# attestor-prod lee el attestor para validar la atestación al crearla (--validate).
resource "google_binary_authorization_attestor_iam_member" "attestor_viewer" {
  project  = local.security_project_id
  attestor = google_binary_authorization_attestor.qa_approved.name
  role     = "roles/binaryauthorization.attestorsViewer"
  member   = "serviceAccount:${local.attestor_sa}"
}

