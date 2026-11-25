output "service_name" {
  description = "Nombre del servicio."
  value       = google_cloud_run_v2_service.this.name
}

output "service_uri" {
  description = "URI run.app del servicio (solo responde por el balanceador o desde la red interna)."
  value       = google_cloud_run_v2_service.this.uri
}

output "region" {
  description = "Región del servicio (para el NEG serverless del balanceador)."
  value       = google_cloud_run_v2_service.this.location
}
