mock_provider "google" {
  mock_resource "google_kms_key_ring" {
    defaults = {
      id = "projects/acme-common-security-ab12/locations/us-central1/keyRings/acme-dev-keyring-ab12"
    }
  }
}

variables {
  project_id   = "acme-common-security-ab12"
  location     = "us-central1"
  keyring_name = "acme-dev-keyring-ab12"
  labels = {
    env         = "dev"
    app         = "landing-zone"
    owner       = "platform"
    cost_center = "infra"
    managed_by  = "terraform"
  }
  keys = {
    storage = {
      encrypter_decrypters = ["serviceAccount:service-111@gs-project-accounts.iam.gserviceaccount.com"]
    }
    sql = { rotation_period = "2592000s" }
  }
}

run "llaves_con_rotacion_y_software" {
  command = plan

  assert {
    condition     = google_kms_crypto_key.keys["storage"].rotation_period == "7776000s"
    error_message = "La rotación por default debe ser 90 días (7776000s)."
  }

  assert {
    condition     = google_kms_crypto_key.keys["sql"].rotation_period == "2592000s"
    error_message = "Debe respetarse la rotación dada por llave."
  }

  assert {
    condition     = google_kms_crypto_key.keys["storage"].version_template[0].algorithm == "GOOGLE_SYMMETRIC_ENCRYPTION" && google_kms_crypto_key.keys["storage"].version_template[0].protection_level == "SOFTWARE"
    error_message = "Las llaves deben ser simétricas con protección SOFTWARE."
  }

  assert {
    condition     = google_kms_crypto_key.keys["storage"].labels["env"] == "dev"
    error_message = "Las llaves deben llevar las etiquetas."
  }

  assert {
    condition     = google_kms_key_ring.this.name == "acme-dev-keyring-ab12" && google_kms_key_ring.this.location == "us-central1"
    error_message = "El keyring debe usar el nombre y la región dados."
  }

  assert {
    condition     = length(google_kms_crypto_key_iam_member.encrypter_decrypter) == 1
    error_message = "Debe haber un binding por (llave, miembro)."
  }

  assert {
    condition     = google_kms_crypto_key_iam_member.encrypter_decrypter["storage/serviceAccount:service-111@gs-project-accounts.iam.gserviceaccount.com"].role == "roles/cloudkms.cryptoKeyEncrypterDecrypter"
    error_message = "El binding debe otorgar cryptoKeyEncrypterDecrypter."
  }
}

run "rotacion_mayor_a_90_dias_falla" {
  command = plan

  variables {
    keys = { storage = { rotation_period = "7862400s" } }
  }

  expect_failures = [var.keys]
}

run "etiquetas_incompletas_falla" {
  command = plan

  variables {
    labels = { env = "dev" }
  }

  expect_failures = [var.labels]
}

run "region_invalida_falla" {
  command = plan

  variables {
    location = "central"
  }

  expect_failures = [var.location]
}
