mock_provider "google" {}

variables {
  name         = "acme-dev-data-pg"
  project_id   = "acme-dev-data-ab12"
  region       = "us-central1"
  network      = "projects/acme-dev-net-host-ab12/global/networks/acme-dev-net-vpc"
  kms_key_name = "projects/acme-common-security-ab12/locations/us-central1/keyRings/kr/cryptoKeys/sql"
  labels = {
    env = "dev", app = "landing-zone", owner = "plataforma", cost_center = "TI-001", managed_by = "terraform"
  }
}

run "primaria_privada_cifrada_y_con_pitr" {
  command = plan

  assert {
    condition     = google_sql_database_instance.primary.settings[0].ip_configuration[0].ipv4_enabled == false
    error_message = "La instancia no debe tener IP pública."
  }

  assert {
    condition     = google_sql_database_instance.primary.settings[0].ip_configuration[0].private_network == var.network
    error_message = "La instancia debe usar IP privada en la red dada."
  }

  assert {
    condition     = google_sql_database_instance.primary.settings[0].ip_configuration[0].ssl_mode == "ENCRYPTED_ONLY"
    error_message = "La instancia debe exigir SSL."
  }

  assert {
    condition     = google_sql_database_instance.primary.encryption_key_name == var.kms_key_name
    error_message = "La instancia debe usar CMEK."
  }

  assert {
    condition     = google_sql_database_instance.primary.settings[0].backup_configuration[0].point_in_time_recovery_enabled
    error_message = "PITR debe estar activo."
  }

  assert {
    condition     = contains([for f in google_sql_database_instance.primary.settings[0].database_flags : "${f.name}=${f.value}"], "cloudsql.iam_authentication=on")
    error_message = "La autenticación IAM debe estar activa."
  }

  assert {
    condition     = google_sql_database_instance.primary.settings[0].edition == "ENTERPRISE"
    error_message = "La primaria debe ser edición ENTERPRISE (Enterprise Plus no acepta tiers db-custom)."
  }

  assert {
    condition     = google_sql_database_instance.primary.settings[0].availability_type == "ZONAL"
    error_message = "Sin HA la instancia es zonal."
  }

  assert {
    condition     = length(google_sql_database_instance.replica) == 0
    error_message = "Sin enable_dr_replica no hay réplica."
  }
}

run "prod_con_ha_y_replica_dr" {
  command = plan

  variables {
    ha                = true
    enable_dr_replica = true
    dr_kms_key_name   = "projects/acme-common-security-ab12/locations/us-east4/keyRings/kr/cryptoKeys/sql-dr"
  }

  assert {
    condition     = google_sql_database_instance.primary.settings[0].availability_type == "REGIONAL"
    error_message = "Con HA la instancia es regional."
  }

  assert {
    condition     = google_sql_database_instance.replica[0].settings[0].edition == "ENTERPRISE"
    error_message = "La réplica DR debe ser edición ENTERPRISE (Enterprise Plus no acepta tiers db-custom)."
  }

  assert {
    condition     = google_sql_database_instance.replica[0].region == "us-east4"
    error_message = "La réplica DR va en us-east4."
  }

  assert {
    condition     = google_sql_database_instance.replica[0].encryption_key_name == var.dr_kms_key_name
    error_message = "La réplica usa su propia llave en la región DR."
  }

  assert {
    condition     = google_sql_database_instance.replica[0].settings[0].ip_configuration[0].ipv4_enabled == false
    error_message = "La réplica tampoco tiene IP pública."
  }
}

run "replica_sin_llave_dr_falla" {
  command = plan

  variables {
    enable_dr_replica = true
  }

  expect_failures = [var.dr_kms_key_name]
}

run "rechaza_etiquetas_incompletas" {
  command = plan

  variables {
    labels = { env = "dev" }
  }

  expect_failures = [var.labels]
}
