# Firewall jerárquico de la organización: base común; el aislamiento por entorno lo hace cada VPC.

locals {
  firewall_rules = {
    "allow-iap" = {
      priority    = 1000
      description = "SSH y RDP desde Identity-Aware Proxy"
      action      = "allow"
      src_ranges  = ["35.235.240.0/20"]
      protocol    = "tcp"
      ports       = ["22", "3389"]
    }
    "allow-health-checks" = {
      priority    = 1001
      description = "Comprobaciones de salud de Google Cloud"
      action      = "allow"
      src_ranges  = ["35.191.0.0/16", "130.211.0.0/22"]
      protocol    = "tcp"
      ports       = null
    }
    "goto-next-ingress" = {
      priority    = 65000
      description = "El resto del tráfico lo evalúan las reglas de cada VPC"
      action      = "goto_next"
      src_ranges  = ["0.0.0.0/0"]
      protocol    = "all"
      ports       = null
    }
  }
}

resource "google_compute_firewall_policy" "org" {
  parent      = local.org
  short_name  = "${var.prefix}-org-baseline"
  description = "Base de firewall jerárquico de la organización"
}

resource "google_compute_firewall_policy_rule" "rules" {
  for_each = local.firewall_rules

  firewall_policy = google_compute_firewall_policy.org.name
  priority        = each.value.priority
  description     = each.value.description
  action          = each.value.action
  direction       = "INGRESS"
  enable_logging  = each.value.action == "allow"

  match {
    src_ip_ranges = each.value.src_ranges

    layer4_configs {
      ip_protocol = each.value.protocol
      ports       = each.value.ports
    }
  }
}

resource "google_compute_firewall_policy_association" "org" {
  name              = "${var.prefix}-org-baseline"
  firewall_policy   = google_compute_firewall_policy.org.id
  attachment_target = local.org
}
