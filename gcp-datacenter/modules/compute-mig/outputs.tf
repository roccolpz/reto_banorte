output "mig_name" {
  description = "Nombre del MIG regional."
  value       = google_compute_region_instance_group_manager.this.name
}

output "instance_group" {
  description = "URL del grupo de instancias (para backends de balanceo)."
  value       = google_compute_region_instance_group_manager.this.instance_group
}

output "instance_template_id" {
  description = "ID de la plantilla de instancia."
  value       = google_compute_instance_template.this.id
}

output "health_check_id" {
  description = "ID del health check de autocuración."
  value       = google_compute_health_check.this.id
}
