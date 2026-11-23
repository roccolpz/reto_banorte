mock_provider "google" {}

variables {
  name            = "acme dev app"
  project_id      = "acme-dev-app-a1b2"
  folder_id       = "folders/123456789012"
  billing_account = "000000-000000-000000"
  activate_apis   = ["compute.googleapis.com", "container.googleapis.com"]
  labels = {
    env         = "dev"
    app         = "landing-zone"
    owner       = "plataforma"
    cost_center = "cc-0000"
    managed_by  = "terraform"
  }
}

run "proyecto_sin_red_por_defecto_ni_shared_vpc" {
  command = plan

  assert {
    condition     = google_project.project.auto_create_network == false
    error_message = "El proyecto no debe crear la red default."
  }

  assert {
    condition     = google_project.project.deletion_policy == "DELETE"
    error_message = "deletion_policy debe ser DELETE por defecto."
  }

  assert {
    condition     = google_project.project.labels["managed_by"] == "terraform"
    error_message = "Las etiquetas deben llegar al proyecto."
  }

  assert {
    condition     = length(google_project_service.services) == 2
    error_message = "Debe habilitar una API por elemento de activate_apis."
  }

  assert {
    condition     = length(google_compute_shared_vpc_service_project.service_project) == 0
    error_message = "Sin host de Shared VPC no se adjunta como proyecto de servicio."
  }
}

run "adjunta_a_shared_vpc_cuando_hay_host" {
  command = plan

  variables {
    shared_vpc_host_project_id = "acme-dev-net-host-a1b2"
    deletion_policy            = "PREVENT"
  }

  assert {
    condition     = google_compute_shared_vpc_service_project.service_project[0].host_project == "acme-dev-net-host-a1b2"
    error_message = "Debe adjuntarse al host indicado."
  }

  assert {
    condition     = google_project.project.deletion_policy == "PREVENT"
    error_message = "deletion_policy debe ser configurable."
  }
}

run "falla_si_faltan_etiquetas_obligatorias" {
  command = plan

  variables {
    labels = { env = "dev", app = "landing-zone" }
  }

  expect_failures = [var.labels]
}

run "falla_sin_etiquetas" {
  command = plan

  variables {
    labels = {}
  }

  expect_failures = [var.labels]
}

run "falla_con_deletion_policy_invalida" {
  command = plan

  variables {
    deletion_policy = "BORRAR"
  }

  expect_failures = [var.deletion_policy]
}

run "falla_con_project_id_invalido" {
  command = plan

  variables {
    project_id = "Acme_Dev"
  }

  expect_failures = [var.project_id]
}
