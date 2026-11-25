mock_provider "google" {}

variables {
  name       = "acme-prod-data-redis"
  project_id = "acme-prod-data-ab12"
  network    = "projects/acme-prod-net-host-ab12/global/networks/acme-prod-net-vpc"
  labels = {
    env = "prod", app = "landing-zone", owner = "plataforma", cost_center = "TI-001", managed_by = "terraform"
  }
}

run "privada_con_auth_y_tls" {
  command = plan

  assert {
    condition     = google_redis_instance.this.connect_mode == "PRIVATE_SERVICE_ACCESS"
    error_message = "La instancia usa acceso a servicios privados."
  }

  assert {
    condition     = google_redis_instance.this.auth_enabled && google_redis_instance.this.transit_encryption_mode == "SERVER_AUTHENTICATION"
    error_message = "AUTH y cifrado en tránsito activos."
  }

  assert {
    condition     = google_redis_instance.this.tier == "BASIC" && google_redis_instance.this.memory_size_gb == 1
    error_message = "Por defecto BASIC de 1 GB."
  }
}

run "rechaza_tier_invalido" {
  command = plan

  variables {
    tier = "PREMIUM"
  }

  expect_failures = [var.tier]
}
