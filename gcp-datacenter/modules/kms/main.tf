resource "google_kms_key_ring" "this" {
  project  = var.project_id
  name     = var.keyring_name
  location = var.location
}

# Las llaves no se borran en GCP: `terraform destroy` solo programa la destrucción de sus versiones.
# prevent_destroy no acepta variables; la raíz que llama decide si lo agrega con su propio lifecycle.
resource "google_kms_crypto_key" "keys" {
  for_each = var.keys

  name            = each.key
  key_ring        = google_kms_key_ring.this.id
  purpose         = "ENCRYPT_DECRYPT"
  rotation_period = each.value.rotation_period
  labels          = var.labels

  version_template {
    algorithm        = "GOOGLE_SYMMETRIC_ENCRYPTION"
    protection_level = "SOFTWARE"
  }
}

resource "google_kms_crypto_key_iam_member" "encrypter_decrypter" {
  for_each = {
    for pair in flatten([
      for key, cfg in var.keys : [for m in cfg.encrypter_decrypters : { key = key, member = m }]
    ]) : "${pair.key}/${pair.member}" => pair
  }

  crypto_key_id = google_kms_crypto_key.keys[each.value.key].id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = each.value.member
}
