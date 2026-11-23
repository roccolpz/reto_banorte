mock_provider "google" {}

variables {
  name                  = "acme-dev-app-probe"
  project_id            = "acme-dev-app-ab12"
  region                = "us-central1"
  subnetwork            = "projects/acme-dev-net-host-ab12/regions/us-central1/subnetworks/acme-dev-net-app-usc1"
  service_account_email = "acme-dev-vm@acme-dev-app-ab12.iam.gserviceaccount.com"
  labels = {
    env = "dev", app = "landing-zone", owner = "plataforma", cost_center = "TI-001", managed_by = "terraform"
  }
}

run "plantilla_endurecida_y_mig_regional" {
  command = plan

  assert {
    condition     = google_compute_instance_template.this.machine_type == "e2-micro"
    error_message = "Por defecto la VM es e2-micro."
  }

  assert {
    condition     = length(google_compute_instance_template.this.network_interface[0].access_config) == 0
    error_message = "La VM no debe tener IP externa."
  }

  assert {
    condition     = google_compute_instance_template.this.shielded_instance_config[0].enable_secure_boot
    error_message = "La VM debe ser Shielded VM con secure boot."
  }

  assert {
    condition     = google_compute_instance_template.this.metadata["enable-oslogin"] == "TRUE"
    error_message = "OS Login debe estar activo."
  }

  assert {
    condition     = google_compute_instance_template.this.service_account[0].email == var.service_account_email
    error_message = "La VM usa la SA dada."
  }

  assert {
    condition     = google_compute_region_instance_group_manager.this.region == "us-central1"
    error_message = "El MIG es regional."
  }

  assert {
    condition     = google_compute_region_instance_group_manager.this.auto_healing_policies[0].initial_delay_sec == 300
    error_message = "El MIG debe tener autocuración."
  }
}

run "rechaza_etiquetas_incompletas" {
  command = plan

  variables {
    labels = { env = "dev" }
  }

  expect_failures = [var.labels]
}
