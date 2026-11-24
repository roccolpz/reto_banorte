mock_provider "google" {}

variables {
  name         = "acme-dev-data-files-ab12"
  project_id   = "acme-dev-data-ab12"
  kms_key_name = "projects/acme-common-security-ab12/locations/us-central1/keyRings/kr/cryptoKeys/storage"
  labels = {
    env = "dev", app = "landing-zone", owner = "plataforma", cost_center = "TI-001", managed_by = "terraform"
  }
}

run "bucket_regional_seguro_por_defecto" {
  command = plan

  assert {
    condition     = google_storage_bucket.this.location == "US-CENTRAL1"
    error_message = "Por defecto el bucket es regional en us-central1."
  }

  assert {
    condition     = google_storage_bucket.this.encryption[0].default_kms_key_name == var.kms_key_name
    error_message = "El bucket debe usar CMEK."
  }

  assert {
    condition     = google_storage_bucket.this.versioning[0].enabled
    error_message = "El versionado debe estar activo."
  }

  assert {
    condition     = google_storage_bucket.this.uniform_bucket_level_access
    error_message = "El acceso uniforme debe estar activo."
  }

  assert {
    condition     = google_storage_bucket.this.public_access_prevention == "enforced"
    error_message = "La prevención de acceso público debe estar forzada."
  }

  assert {
    condition     = length(google_storage_bucket.this.lifecycle_rule) == 2
    error_message = "Por defecto hay dos reglas de ciclo de vida."
  }

  assert {
    condition     = length(google_storage_bucket.this.custom_placement_config) == 0
    error_message = "Sin dual_region el bucket es de una sola región."
  }
}

run "dual_region_con_turbo" {
  command = plan

  variables {
    location          = "US"
    dual_region       = ["US-CENTRAL1", "US-EAST4"]
    turbo_replication = true
  }

  assert {
    condition     = google_storage_bucket.this.custom_placement_config[0].data_locations == toset(["US-CENTRAL1", "US-EAST4"])
    error_message = "El bucket debe ser dual-region us-central1 + us-east4."
  }

  assert {
    condition     = google_storage_bucket.this.rpo == "ASYNC_TURBO"
    error_message = "Turbo replication fija rpo = ASYNC_TURBO."
  }
}

run "turbo_sin_dual_region_falla" {
  command = plan

  variables {
    turbo_replication = true
  }

  expect_failures = [var.turbo_replication]
}

run "rechaza_etiquetas_incompletas" {
  command = plan

  variables {
    labels = { env = "dev" }
  }

  expect_failures = [var.labels]
}
