# Política de firewall de red asociada a la VPC. Las reglas con target_tags apuntan a etiquetas
# seguras (Resource Manager, propósito GCE_FIREWALL); sin target_tags aplican a toda la VPC.

resource "google_tags_tag_key" "this" {
  count = length(var.secure_tags) > 0 ? 1 : 0

  parent       = "projects/${var.project_id}"
  short_name   = "${var.name_prefix}-fw"
  description  = "Etiquetas seguras de firewall de ${basename(var.network)}."
  purpose      = "GCE_FIREWALL"
  purpose_data = { network = "${var.project_id}/${basename(var.network)}" }
}

resource "google_tags_tag_value" "this" {
  for_each = toset(var.secure_tags)

  parent      = google_tags_tag_key.this[0].id
  short_name  = each.key
  description = "Destino de reglas de firewall: ${each.key}."
}

resource "google_compute_network_firewall_policy" "this" {
  project     = var.project_id
  name        = "${var.name_prefix}-fwp"
  description = "Política de firewall de ${basename(var.network)}."
}

resource "google_compute_network_firewall_policy_association" "this" {
  project           = var.project_id
  name              = "${var.name_prefix}-fwp-assoc"
  firewall_policy   = google_compute_network_firewall_policy.this.name
  attachment_target = var.network
}

resource "google_compute_network_firewall_policy_rule" "this" {
  for_each = var.rules

  project         = var.project_id
  firewall_policy = google_compute_network_firewall_policy.this.name
  rule_name       = "${var.name_prefix}-fw-${each.key}"
  description     = each.value.description
  direction       = each.value.direction
  action          = each.value.action
  priority        = each.value.priority
  enable_logging  = each.value.enable_logging

  match {
    src_ip_ranges  = each.value.direction == "INGRESS" ? each.value.ranges : null
    dest_ip_ranges = each.value.direction == "EGRESS" ? each.value.ranges : null

    dynamic "layer4_configs" {
      for_each = each.value.protocols
      content {
        ip_protocol = layer4_configs.value.protocol
        ports       = layer4_configs.value.ports
      }
    }
  }

  dynamic "target_secure_tags" {
    for_each = each.value.target_tags
    content {
      name = google_tags_tag_value.this[target_secure_tags.value].id
    }
  }
}
