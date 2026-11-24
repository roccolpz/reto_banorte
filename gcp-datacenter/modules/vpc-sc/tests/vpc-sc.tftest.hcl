mock_provider "google" {}

variables {
  perimeter_name      = "acme_dev_perimeter"
  access_policy_name  = "123456789"
  restricted_services = ["storage.googleapis.com", "sqladmin.googleapis.com"]
  member_projects     = ["111111111111"]
}

# Sin `enforce` el perímetro queda en dry-run (CONTRATO §8).
run "default_es_dry_run" {
  command = plan

  assert {
    condition     = google_access_context_manager_service_perimeter.perimeter.name == "accessPolicies/123456789/servicePerimeters/acme_dev_perimeter"
    error_message = "El nombre del perímetro no sigue accessPolicies/<n>/servicePerimeters/<nombre>."
  }

  assert {
    condition     = length(google_access_context_manager_service_perimeter.perimeter.status) == 0 && length(google_access_context_manager_service_perimeter.perimeter.spec) == 1
    error_message = "Sin enforce solo debe existir el bloque spec (dry-run)."
  }

  assert {
    condition     = google_access_context_manager_service_perimeter.perimeter.spec[0].resources == toset(["projects/111111111111"])
    error_message = "member_projects debe convertirse a projects/<número>."
  }

  assert {
    condition     = output.enforced == false
    error_message = "La salida enforced debe ser false en dry-run."
  }
}

run "aplicado_usa_status" {
  command = plan

  variables {
    enforce = true
  }

  assert {
    condition     = length(google_access_context_manager_service_perimeter.perimeter.status) == 1 && length(google_access_context_manager_service_perimeter.perimeter.spec) == 0
    error_message = "Con enforce = true solo debe existir el bloque status."
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

}

# Fase 3 §5.2: cada regla de egreso nombra identidades, destinos y servicios.
run "egreso_explicito" {
  command = plan

  variables {
    enforce = true
    egress_rules = [{
      identities = ["serviceAccount:app-workload@acme-dev-app-ab12.iam.gserviceaccount.com"]
      resources  = ["projects/222222222222"]
      services   = ["storage.googleapis.com"]
    }]
  }

  assert {
    condition     = length(google_access_context_manager_service_perimeter.perimeter.status[0].egress_policies) == 1
    error_message = "Cada elemento de egress_rules debe crear una regla de egreso."
  }

  assert {
    condition     = google_access_context_manager_service_perimeter.perimeter.status[0].egress_policies[0].egress_from[0].identities == toset(["serviceAccount:app-workload@acme-dev-app-ab12.iam.gserviceaccount.com"])
    error_message = "La regla de egreso debe listar solo las identidades dadas."
  }

  assert {
    condition     = google_access_context_manager_service_perimeter.perimeter.status[0].egress_policies[0].egress_to[0].resources == toset(["projects/222222222222"])
    error_message = "El destino de la regla de egreso debe ser el proyecto dado, no '*'."
  }

  assert {
    condition     = [for o in google_access_context_manager_service_perimeter.perimeter.status[0].egress_policies[0].egress_to[0].operations : o.service_name] == ["storage.googleapis.com"]
    error_message = "La regla de egreso debe permitir solo los servicios dados."
  }
}

run "egreso_destino_invalido_falla" {
  command = plan

  variables {
    egress_rules = [{
      identities = ["serviceAccount:app-workload@acme-dev-app-ab12.iam.gserviceaccount.com"]
      resources  = ["*"]
      services   = ["storage.googleapis.com"]
    }]
  }

  expect_failures = [var.egress_rules]
}

run "sin_identidades_no_hay_reglas" {
  command = plan

  assert {
    condition     = length(google_access_context_manager_service_perimeter.perimeter.spec[0].ingress_policies) == 0 && length(google_access_context_manager_service_perimeter.perimeter.spec[0].egress_policies) == 0
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
