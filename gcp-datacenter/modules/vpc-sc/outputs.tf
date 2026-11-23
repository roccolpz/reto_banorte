output "name" {
  description = "Nombre completo del perímetro: accessPolicies/<n>/servicePerimeters/<nombre>."
  value       = google_access_context_manager_service_perimeter.perimeter.name
}

output "enforced" {
  description = "true si la configuración está aplicada (status); false si está en dry-run (spec)."
  value       = var.enforce
}
