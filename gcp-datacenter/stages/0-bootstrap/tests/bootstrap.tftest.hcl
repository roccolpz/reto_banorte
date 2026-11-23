# Pruebas de la raíz 0-bootstrap con proveedor simulado: no tocan GCP.
# command = apply con mocks para que los atributos calculados (nombre del pool WIF) tengan valor.
mock_provider "google" {
  # El proveedor valida el formato del nombre de la SA; el mock por defecto genera texto aleatorio.
  mock_resource "google_service_account" {
    defaults = {
      name   = "projects/acme-bootstrap-seed-a1b2/serviceAccounts/sa-tf-mock@acme-bootstrap-seed-a1b2.iam.gserviceaccount.com"
      email  = "sa-tf-mock@acme-bootstrap-seed-a1b2.iam.gserviceaccount.com"
      member = "serviceAccount:sa-tf-mock@acme-bootstrap-seed-a1b2.iam.gserviceaccount.com"
    }
  }
}

variables {
  org_id          = "000000000000"
  billing_account = "000000-000000-000000"
  suffix          = "a1b2"
  labels = {
    app         = "landing-zone"
    owner       = "plataforma"
    cost_center = "cc-0000"
  }
}

run "crea_una_sa_por_etapa_y_limita_prod_al_environment_prod" {
  command = apply

  assert {
    condition     = length(output.stage_service_accounts) == 13
    error_message = "Debe haber 13 SA: plan y una por etapa y entorno."
  }

  assert {
    condition     = endswith(google_service_account_iam_member.wif["5-workloads-prod"].member, "/attribute.environment/prod")
    error_message = "Las SA de prod solo se impersonan desde el environment prod de GitHub."
  }

  assert {
    condition     = endswith(google_service_account_iam_member.wif["5-workloads-dev"].member, "/attribute.repository/roccolpz/reto_banorte")
    error_message = "Las SA que no son de prod se impersonan desde el repositorio autorizado."
  }

  assert {
    condition     = google_iam_workload_identity_pool_provider.github.attribute_condition == "assertion.repository == \"roccolpz/reto_banorte\""
    error_message = "WIF debe aceptar solo el repositorio autorizado."
  }
}

run "bucket_de_estado_cifrado_y_escritura_por_prefijo" {
  command = apply

  assert {
    condition     = google_storage_bucket.state.public_access_prevention == "enforced" && google_storage_bucket.state.uniform_bucket_level_access && google_storage_bucket.state.versioning[0].enabled
    error_message = "El bucket de estado debe ser privado, con acceso uniforme y versionado."
  }

  assert {
    condition     = google_storage_bucket.state.location == "US-CENTRAL1" || google_storage_bucket.state.location == "us-central1"
    error_message = "El bucket de estado vive en us-central1."
  }

  assert {
    condition     = google_kms_crypto_key.state.rotation_period == "7776000s"
    error_message = "La llave del estado rota cada 90 días."
  }

  assert {
    condition     = strcontains(google_storage_bucket_iam_member.stage_writer["3-networks-dev"].condition[0].expression, "/objects/3-networks/dev/")
    error_message = "Cada SA escribe solo bajo el prefijo de su etapa."
  }

  assert {
    condition     = !contains(keys(google_storage_bucket_iam_member.stage_writer), "plan")
    error_message = "La SA de plan no puede escribir estado."
  }

  assert {
    condition     = contains(keys(google_storage_bucket_iam_member.state_reader), "plan")
    error_message = "La SA de plan lee todo el estado."
  }
}

run "falla_con_sufijo_invalido" {
  command = plan

  variables {
    suffix = "XYZ"
  }

  expect_failures = [var.suffix]
}
