locals {
  # Sin dominio propio se usa <ip>.nip.io, que resuelve a la IP del balanceador: el certificado administrado se
  # puede emitir sin zona DNS pública.
  domain = coalesce(var.domain, "${google_compute_global_address.this.address}.nip.io")

  # Reglas WAF preconfiguradas de Cloud Armor (OWASP Top 10): bloquean con 403. Log4j va aparte, en un bloque fijo.
  waf_rules = {
    1000 = { rule = "sqli-v33-stable", description = "OWASP: inyección SQL" }
    1001 = { rule = "xss-v33-stable", description = "OWASP: cross-site scripting" }
    1002 = { rule = "lfi-v33-stable", description = "OWASP: inclusión de archivos locales" }
    1003 = { rule = "rce-v33-stable", description = "OWASP: ejecución remota de código" }
  }
}

resource "google_compute_global_address" "this" {
  name    = "${var.name}-ip"
  project = var.project_id
  labels  = var.labels
}

# --- Cloud Armor ---

resource "google_compute_security_policy" "this" {
  name        = "${var.name}-armor"
  project     = var.project_id
  description = "WAF OWASP del balanceador ${var.name}"

  dynamic "rule" {
    for_each = local.waf_rules
    content {
      action      = "deny(403)"
      priority    = rule.key
      description = rule.value.description
      preview     = false
      match {
        expr {
          expression = "evaluatePreconfiguredWaf('${rule.value.rule}', {'sensitivity': ${var.waf_sensitivity}})"
        }
      }
    }
  }

  # Bloque fijo (no dinámico) para que Checkov lo reconozca (CKV_GCP_73).
  rule {
    action      = "deny(403)"
    priority    = 1004
    description = "CVE-2021-44228 y CVE-2021-45046 (Log4j)"
    preview     = false
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('cve-canary')"
      }
    }
  }

  rule {
    action      = "allow"
    priority    = 2147483647
    description = "Regla por defecto"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
  }
}

# --- Backend: Cloud Run por NEG serverless ---

resource "google_compute_region_network_endpoint_group" "this" {
  name                  = "${var.name}-neg"
  project               = var.project_id
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = var.cloud_run_service
  }
}

resource "google_compute_backend_service" "this" {
  name                  = "${var.name}-backend"
  project               = var.project_id
  load_balancing_scheme = "EXTERNAL_MANAGED"
  protocol              = "HTTPS"
  security_policy       = google_compute_security_policy.this.id

  backend {
    group = google_compute_region_network_endpoint_group.this.id
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

resource "google_compute_url_map" "this" {
  name            = "${var.name}-urlmap"
  project         = var.project_id
  default_service = google_compute_backend_service.this.id
}

# --- Frontend HTTPS ---

resource "google_compute_managed_ssl_certificate" "this" {
  name    = "${var.name}-cert"
  project = var.project_id

  managed {
    domains = [local.domain]
  }
}

resource "google_compute_ssl_policy" "this" {
  name            = "${var.name}-tls"
  project         = var.project_id
  profile         = "MODERN"
  min_tls_version = "TLS_1_2"
}

resource "google_compute_target_https_proxy" "this" {
  name             = "${var.name}-https"
  project          = var.project_id
  url_map          = google_compute_url_map.this.id
  ssl_certificates = [google_compute_managed_ssl_certificate.this.id]
  ssl_policy       = google_compute_ssl_policy.this.id
}

resource "google_compute_global_forwarding_rule" "https" {
  name                  = "${var.name}-https"
  project               = var.project_id
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_address            = google_compute_global_address.this.id
  port_range            = "443"
  target                = google_compute_target_https_proxy.this.id
  labels                = var.labels
}
