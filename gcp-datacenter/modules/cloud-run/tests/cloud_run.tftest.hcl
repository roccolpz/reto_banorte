mock_provider "google" {}

variables {
  name                  = "acme-dev-app-run"
  project_id            = "acme-dev-app-ab12"
  service_account_email = "cloud-run@acme-dev-app-ab12.iam.gserviceaccount.com"
  labels = {
    env = "dev", app = "landing-zone", owner = "plataforma", cost_center = "TI-001", managed_by = "terraform"
  }
}

run "solo_balanceador_y_escala_a_cero" {
  command = plan

  assert {
    condition     = google_cloud_run_v2_service.this.ingress == "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
    error_message = "Por defecto solo el balanceador llega al servicio."
  }

  assert {
    condition     = google_cloud_run_v2_service.this.template[0].scaling[0].min_instance_count == 0
    error_message = "Por defecto escala a cero."
  }

  assert {
    condition     = google_cloud_run_v2_service.this.template[0].service_account == var.service_account_email
    error_message = "El servicio corre con la cuenta dedicada."
  }
}

run "rechaza_ingreso_publico" {
  command = plan

  variables {
    ingress = "INGRESS_TRAFFIC_ALL"
  }

  expect_failures = [var.ingress]
}

run "rechaza_etiquetas_incompletas" {
  command = plan

  variables {
    labels = { env = "dev" }
  }

  expect_failures = [var.labels]
}
