output "cluster_name" {
  description = "Nombre del cluster."
  value       = google_container_cluster.primary.name
}

output "cluster_id" {
  description = "ID del cluster (projects/<p>/locations/<l>/clusters/<n>)."
  value       = google_container_cluster.primary.id
}

output "location" {
  description = "Región o zona del cluster."
  value       = google_container_cluster.primary.location
}

output "cluster_endpoint" {
  description = "Endpoint del plano de control."
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}

output "workload_pool" {
  description = "Pool de Workload Identity, o null si está desactivado."
  value       = var.enable_workload_identity ? "${var.project_id}.svc.id.goog" : null
}
