mock_provider "google" {}

variables {
  project_id  = "acme-dev-net-host-0000"
  network     = "https://www.googleapis.com/compute/v1/projects/acme-dev-net-host-0000/global/networks/acme-dev-net-vpc"
  name_prefix = "acme-dev-net"
  labels = {
    env         = "dev"
    app         = "network"
    owner       = "network-team"
    cost_center = "infra"
    managed_by  = "terraform"
  }
}

run "politica_con_etiquetas_seguras" {
  command = plan

  variables {
    secure_tags = ["gke-nodes", "vm"]
    rules = {
      allow-gke-master = {
        priority    = 1000
        ranges      = ["172.16.10.0/28"]
        protocols   = [{ protocol = "tcp", ports = ["443", "10250"] }]
        target_tags = ["gke-nodes"]
      }
      deny-all-ingress = {
        action         = "deny"
        priority       = 65000
        ranges         = ["0.0.0.0/0"]
        enable_logging = true
      }
    }
  }

  assert {
    condition     = google_tags_tag_key.this[0].purpose == "GCE_FIREWALL" && google_tags_tag_key.this[0].purpose_data["network"] == "acme-dev-net-host-0000/acme-dev-net-vpc" && google_tags_tag_key.this[0].parent == "projects/acme-dev-net-host-0000"
    error_message = "La llave de etiqueta segura debe tener propósito GCE_FIREWALL ligado a la VPC."
  }

  assert {
    condition     = toset(keys(google_tags_tag_value.this)) == toset(["gke-nodes", "vm"])
    error_message = "Debe existir un valor de etiqueta por cada secure_tags."
  }

  assert {
    condition     = google_compute_network_firewall_policy.this.name == "acme-dev-net-fwp" && google_compute_network_firewall_policy_association.this.attachment_target == var.network
    error_message = "La política de firewall de red debe asociarse a la VPC."
  }

  assert {
    condition     = google_compute_network_firewall_policy_rule.this["allow-gke-master"].match[0].src_ip_ranges == tolist(["172.16.10.0/28"]) && google_compute_network_firewall_policy_rule.this["allow-gke-master"].match[0].layer4_configs[0].ports == tolist(["443", "10250"])
    error_message = "allow-gke-master: origen y puertos de la regla."
  }

  assert {
    condition     = length(google_compute_network_firewall_policy_rule.this["allow-gke-master"].target_secure_tags) == 1 && length(google_compute_network_firewall_policy_rule.this["deny-all-ingress"].target_secure_tags) == 0
    error_message = "Solo las reglas con target_tags apuntan a etiquetas seguras; sin target_tags aplican a toda la VPC."
  }

  assert {
    condition     = google_compute_network_firewall_policy_rule.this["deny-all-ingress"].action == "deny" && google_compute_network_firewall_policy_rule.this["deny-all-ingress"].enable_logging == true && google_compute_network_firewall_policy_rule.this["deny-all-ingress"].rule_name == "acme-dev-net-fw-deny-all-ingress"
    error_message = "deny-all-ingress: deny, con logging y nombre <name_prefix>-fw-<llave>."
  }
}

run "sin_etiquetas_no_crea_llave" {
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
    condition     = length(google_tags_tag_key.this) == 0 && keys(google_compute_network_firewall_policy_rule.this) == ["allow-dns"]
    error_message = "Sin secure_tags no se crea llave; solo existen las reglas pasadas."
  }

  assert {
    condition     = length(google_compute_network_firewall_policy_rule.this["allow-dns"].match[0].layer4_configs) == 2
    error_message = "allow-dns debe tener dos layer4_configs (udp y tcp)."
  }
}

run "rechaza_etiqueta_desconocida" {
  command = plan

  variables {
    secure_tags = ["vm"]
    rules = {
      bad = { ranges = ["10.0.0.0/8"], target_tags = ["gke-nodes"] }
    }
  }

  expect_failures = [var.rules]
}

run "rechaza_prioridad_repetida" {
  command = plan

  variables {
    rules = {
      a = { ranges = ["10.0.0.0/8"], priority = 1000 }
      b = { ranges = ["10.1.0.0/16"], priority = 1000 }
    }
  }

  expect_failures = [var.rules]
}

run "rechaza_accion_invalida" {
  command = plan

  variables {
    rules = {
      bad = { ranges = ["10.0.0.0/8"], action = "drop" }
    }
  }

  expect_failures = [var.rules]
}

run "rechaza_etiquetas_incompletas" {
  command = plan

  variables {
    labels = { env = "dev" }
  }

  expect_failures = [var.labels]
}
