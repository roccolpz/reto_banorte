output "policy_id" {
  description = "ID de la política de firewall de red."
  value       = google_compute_network_firewall_policy.this.id
}

output "rule_names" {
  description = "Mapa llave de regla -> nombre de la regla creada."
  value       = { for k, r in google_compute_network_firewall_policy_rule.this : k => r.rule_name }
}

output "secure_tag_values" {
  description = "Mapa nombre corto -> `tagValues/<id>` de las etiquetas seguras creadas."
  value       = { for k, v in google_tags_tag_value.this : k => v.id }
}
