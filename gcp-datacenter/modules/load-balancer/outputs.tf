output "ip_address" {
  description = "IP pública del balanceador."
  value       = google_compute_global_address.this.address
}

output "domain" {
  description = "Dominio del certificado administrado."
  value       = local.domain
}

output "security_policy_name" {
  description = "Nombre de la política de Cloud Armor."
  value       = google_compute_security_policy.this.name
}
