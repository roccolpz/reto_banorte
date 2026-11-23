locals {
  # Juego base de un entorno. Prioridades: deny entre entornos (900) antes que los allow (1000);
  # deny-all (65000) queda justo encima de las reglas implícitas de GCP para dejar rastro en logs.
  base_rules = {
    deny-all-ingress = {
      description    = "Niega todo el ingreso no permitido explícitamente (con logging)."
      direction      = "INGRESS"
      action         = "deny"
      priority       = 65000
      ranges         = ["0.0.0.0/0"]
      protocols      = [{ protocol = "all", ports = [] }]
      target_tags    = null
      enable_logging = true
    }
    allow-iap = {
      description    = "SSH/RDP solo desde IAP TCP forwarding."
      direction      = "INGRESS"
      action         = "allow"
      priority       = 1000
      ranges         = ["35.235.240.0/20"]
      protocols      = [{ protocol = "tcp", ports = ["22", "3389"] }]
      target_tags    = null
      enable_logging = false
    }
    allow-health-checks = {
      description    = "Health checks de balanceadores de GCP."
      direction      = "INGRESS"
      action         = "allow"
      priority       = 1000
      ranges         = ["130.211.0.0/22", "35.191.0.0/16"]
      protocols      = [{ protocol = "tcp", ports = [] }]
      target_tags    = null
      enable_logging = false
    }
    allow-onprem = {
      description    = "Tráfico desde on-prem por HA VPN."
      direction      = "INGRESS"
      action         = "allow"
      priority       = 1000
      ranges         = var.onprem_cidrs
      protocols      = [{ protocol = "all", ports = [] }]
      target_tags    = null
      enable_logging = false
    }
  }

  deny_envs_rule = length(var.deny_source_cidrs) == 0 ? {} : {
    deny-other-envs = {
      description    = "Aislamiento lateral: niega tráfico desde otros entornos."
      direction      = "INGRESS"
      action         = "deny"
      priority       = 900
      ranges         = var.deny_source_cidrs
      protocols      = [{ protocol = "all", ports = [] }]
      target_tags    = null
      enable_logging = true
    }
  }

  rules = merge(var.default_rules ? merge(local.base_rules, local.deny_envs_rule) : {}, var.rules)
}

resource "google_compute_firewall" "this" {
  for_each = local.rules

  project     = var.project_id
  network     = var.network
  name        = "${var.name_prefix}-fw-${each.key}"
  description = each.value.description
  direction   = each.value.direction
  priority    = each.value.priority

  source_ranges      = each.value.direction == "INGRESS" ? each.value.ranges : null
  destination_ranges = each.value.direction == "EGRESS" ? each.value.ranges : null
  target_tags        = each.value.target_tags

  dynamic "allow" {
    for_each = each.value.action == "allow" ? each.value.protocols : []
    content {
      protocol = allow.value.protocol
      ports    = allow.value.ports
    }
  }

  dynamic "deny" {
    for_each = each.value.action == "deny" ? each.value.protocols : []
    content {
      protocol = deny.value.protocol
      ports    = deny.value.ports
    }
  }

  dynamic "log_config" {
    for_each = each.value.enable_logging ? [1] : []
    content {
      metadata = "INCLUDE_ALL_METADATA"
    }
  }
}
