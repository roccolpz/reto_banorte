mock_provider "google" {
  mock_resource "google_compute_global_address" {
    defaults = { address = "34.1.2.3" }
  }
}

variables {
  name              = "acme-prod-app-lb"
  project_id        = "acme-prod-app-ab12"
  cloud_run_service = "acme-prod-app-run"
  labels = {
    env = "prod", app = "landing-zone", owner = "plataforma", cost_center = "TI-001", managed_by = "terraform"
  }
}

run "https_con_cloud_armor_owasp" {
  command = apply

  assert {
    condition     = google_compute_backend_service.this.security_policy == google_compute_security_policy.this.id
    error_message = "El backend debe usar la política de Cloud Armor."
  }

  assert {
    condition = alltrue([
      for w in ["sqli-v33-stable", "xss-v33-stable", "cve-canary"] :
      anytrue([for r in google_compute_security_policy.this.rule : r.action == "deny(403)" && strcontains(try(r.match[0].expr[0].expression, ""), w)])
    ])
    error_message = "Cloud Armor bloquea SQLi, XSS y Log4j con 403."
  }

  assert {
    condition     = google_compute_global_forwarding_rule.https.port_range == "443"
    error_message = "El frontend es HTTPS en 443."
  }

  assert {
    condition     = output.domain == "34.1.2.3.nip.io"
    error_message = "Sin dominio, el certificado usa <ip>.nip.io."
  }

  assert {
    condition     = google_compute_ssl_policy.this.min_tls_version == "TLS_1_2"
    error_message = "TLS 1.2 como mínimo."
  }
}

run "dominio_propio" {
  command = plan

  variables {
    domain = "app.example.com"
  }

  assert {
    condition     = google_compute_managed_ssl_certificate.this.managed[0].domains == tolist(["app.example.com"])
    error_message = "Con dominio, el certificado lo usa."
  }
}

run "rechaza_sensibilidad_invalida" {
  command = plan

  variables {
    waf_sensitivity = 7
  }

  expect_failures = [var.waf_sensitivity]
}
