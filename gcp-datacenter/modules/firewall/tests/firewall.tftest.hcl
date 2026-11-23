mock_provider "google" {}

variables {
  project_id  = "acme-dev-net-host-0000"
  network     = "projects/acme-dev-net-host-0000/global/networks/acme-dev-net-vpc"
  name_prefix = "acme-dev-net"
  labels = {
    env         = "dev"
    app         = "network"
    owner       = "network-team"
    cost_center = "infra"
    managed_by  = "terraform"
  }
}

run "default_rules_for_env" {
  command = plan

  variables {
    default_rules     = true
    deny_source_cidrs = ["10.20.0.0/16", "10.30.0.0/16", "10.31.0.0/16"]
  }

  assert {
    condition     = length(google_compute_firewall.this) == 5
    error_message = "El juego base debe crear 5 reglas."
  }

  assert {
    condition     = google_compute_firewall.this["deny-all-ingress"].priority == 65000 && length(google_compute_firewall.this["deny-all-ingress"].log_config) == 1
    error_message = "deny-all-ingress debe tener prioridad baja (65000) y logging."
  }

  assert {
    condition     = google_compute_firewall.this["allow-iap"].source_ranges == toset(["35.235.240.0/20"])
    error_message = "allow-iap debe permitir solo 35.235.240.0/20."
  }

  assert {
    condition     = google_compute_firewall.this["allow-health-checks"].source_ranges == toset(["130.211.0.0/22", "35.191.0.0/16"])
    error_message = "allow-health-checks debe usar los rangos de health check de GCP."
  }

  assert {
    condition     = google_compute_firewall.this["allow-onprem"].source_ranges == toset(["192.168.0.0/16"])
    error_message = "allow-onprem debe permitir 192.168.0.0/16."
  }

  assert {
    condition     = length(google_compute_firewall.this["deny-other-envs"].deny) == 1 && google_compute_firewall.this["deny-other-envs"].priority < google_compute_firewall.this["allow-onprem"].priority
    error_message = "deny-other-envs debe negar y evaluarse antes que los allow."
  }

  assert {
    condition     = google_compute_firewall.this["allow-iap"].name == "acme-dev-net-fw-allow-iap"
    error_message = "El nombre debe seguir <name_prefix>-fw-<llave>."
  }
}

run "custom_rules_only" {
  command = plan

  variables {
    rules = {
      allow-dns = {
        ranges    = ["35.199.192.0/19"]
        protocols = [{ protocol = "udp", ports = ["53"] }, { protocol = "tcp", ports = ["53"] }]
      }
    }
  }

  assert {
    condition     = keys(google_compute_firewall.this) == ["allow-dns"]
    error_message = "Sin default_rules solo deben existir las reglas pasadas."
  }

  assert {
    condition     = length(google_compute_firewall.this["allow-dns"].allow) == 2
    error_message = "allow-dns debe tener dos bloques allow (udp y tcp)."
  }
}

run "rejects_bad_action" {
  command = plan

  variables {
    rules = {
      bad = { ranges = ["10.0.0.0/8"], action = "drop" }
    }
  }

  expect_failures = [var.rules]
}

run "rejects_missing_labels" {
  command = plan

  variables {
    labels = { env = "dev" }
  }

  expect_failures = [var.labels]
}
