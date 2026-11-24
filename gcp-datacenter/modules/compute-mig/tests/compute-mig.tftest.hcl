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

run "imagen_endurecida_sin_puerto_serie_y_autoscaler" {
  command = plan

  variables {
    image_family          = "projects/acme-common-images-ab12/global/images/family/acme-debian-12-cis"
    min_replicas          = 2
    max_replicas          = 4
    resource_manager_tags = { "tagKeys/111" = "tagValues/333" }
  }

  assert {
    condition     = google_compute_instance_template.this.disk[0].source_image == "projects/acme-common-images-ab12/global/images/family/acme-debian-12-cis"
    error_message = "La VM arranca de la familia de imagen endurecida dada."
  }

  assert {
    condition     = google_compute_instance_template.this.metadata["serial-port-enable"] == "FALSE"
    error_message = "El puerto serie debe estar apagado."
  }

  assert {
    condition     = google_compute_instance_template.this.resource_manager_tags["tagKeys/111"] == "tagValues/333"
    error_message = "La VM debe llevar la etiqueta segura que usan las reglas de firewall."
  }

  assert {
    condition     = google_compute_region_autoscaler.this.autoscaling_policy[0].min_replicas == 2 && google_compute_region_autoscaler.this.autoscaling_policy[0].max_replicas == 4
    error_message = "El autoscaler usa min_replicas y max_replicas."
  }

  assert {
    condition     = google_compute_region_autoscaler.this.autoscaling_policy[0].cpu_utilization[0].target == 0.6
    error_message = "El autoscaler escala por CPU al 60 % por defecto."
  }
}

run "rechaza_imagen_que_no_es_familia" {
  command = plan

  variables {
    image_family = "debian-cloud/debian-12-bookworm-v20240110"
  }

  expect_failures = [var.image_family]
}

run "rechaza_min_mayor_que_max" {
  command = plan

  variables {
    min_replicas = 3
    max_replicas = 2
  }

  expect_failures = [var.max_replicas]
}

run "rechaza_etiquetas_incompletas" {
  command = plan

  variables {
    labels = { env = "dev" }
  }

  expect_failures = [var.labels]
}
