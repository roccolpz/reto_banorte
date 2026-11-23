mock_provider "google" {}

variables {
  perimeter_name      = "acme_dev_perimeter"
  access_policy_name  = "123456789"
  restricted_services = ["storage.googleapis.com", "sqladmin.googleapis.com"]
  member_projects     = ["111111111111"]
}

# Interfaz legada (stages/test-orchestration): sin `enforce`, el perímetro sigue aplicado en `status`.
run "legado_aplica_en_status" {
  command = plan

  assert {
    condition     = google_access_context_manager_service_perimeter.perimeter.name == "accessPolicies/123456789/servicePerimeters/acme_dev_perimeter"
    error_message = "El nombre del perímetro no sigue accessPolicies/<n>/servicePerimeters/<nombre>."
  }

  assert {
    condition     = length(google_access_context_manager_service_perimeter.perimeter.status) == 1 && length(google_access_context_manager_service_perimeter.perimeter.spec) == 0
    error_message = "Con enforce = true (default legado) solo debe existir el bloque status."
  }

  assert {
    condition     = google_access_context_manager_service_perimeter.perimeter.status[0].resources == toset(["projects/111111111111"])
    error_message = "member_projects debe convertirse a projects/<número>."
  }

  assert {
    condition     = google_access_context_manager_service_perimeter.perimeter.use_explicit_dry_run_spec == false
    error_message = "En modo aplicado no se usa spec de dry-run."
  }
}

run "dry_run_usa_spec" {
  command = plan

  variables {
    enforce            = false
    ingress_identities = ["serviceAccount:sa-tf-plan@acme-bootstrap-seed-ab12.iam.gserviceaccount.com"]
    egress_identities  = ["serviceAccount:sa-tf-plan@acme-bootstrap-seed-ab12.iam.gserviceaccount.com"]
  }

  assert {
    condition     = google_access_context_manager_service_perimeter.perimeter.use_explicit_dry_run_spec == true
    error_message = "Dry-run requiere use_explicit_dry_run_spec = true."
  }

  assert {
    condition     = length(google_access_context_manager_service_perimeter.perimeter.status) == 0 && length(google_access_context_manager_service_perimeter.perimeter.spec) == 1
    error_message = "En dry-run solo debe existir el bloque spec."
  }

  assert {
    condition     = google_access_context_manager_service_perimeter.perimeter.spec[0].restricted_services == toset(["storage.googleapis.com", "sqladmin.googleapis.com"])
    error_message = "Los servicios restringidos deben ir en spec."
  }

  assert {
    condition     = google_access_context_manager_service_perimeter.perimeter.spec[0].ingress_policies[0].ingress_from[0].identities == toset(["serviceAccount:sa-tf-plan@acme-bootstrap-seed-ab12.iam.gserviceaccount.com"])
    error_message = "La regla de ingreso debe listar las identidades dadas."
  }

  assert {
    condition     = length(google_access_context_manager_service_perimeter.perimeter.spec[0].egress_policies) == 1
    error_message = "Debe existir una regla de egreso cuando hay egress_identities."
  }
}

run "sin_identidades_no_hay_reglas" {
  command = plan

  assert {
    condition     = length(google_access_context_manager_service_perimeter.perimeter.status[0].ingress_policies) == 0 && length(google_access_context_manager_service_perimeter.perimeter.status[0].egress_policies) == 0
    error_message = "Sin identidades no se crean reglas de ingreso ni egreso."
  }
}

run "identidad_invalida_falla" {
  command = plan

  variables {
    ingress_identities = ["sa-tf-plan@acme.iam.gserviceaccount.com"]
  }

  expect_failures = [var.ingress_identities]
}

run "servicio_invalido_falla" {
  command = plan

  variables {
    restricted_services = ["storage"]
  }

  expect_failures = [var.restricted_services]
}

run "nombre_invalido_falla" {
  command = plan

  variables {
    perimeter_name = "acme-dev-perimeter"
  }

  expect_failures = [var.perimeter_name]
}
