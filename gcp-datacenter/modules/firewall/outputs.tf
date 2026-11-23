output "rule_names" {
  description = "Mapa llave de regla -> nombre de la regla creada."
  value       = { for k, r in google_compute_firewall.this : k => r.name }
}

output "rule_self_links" {
  description = "Mapa llave de regla -> self link de la regla creada."
  value       = { for k, r in google_compute_firewall.this : k => r.self_link }
}
