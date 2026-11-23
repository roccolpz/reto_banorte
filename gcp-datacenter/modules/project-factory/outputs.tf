# Los consumidores crean recursos en el proyecto con estos valores; esperan a que las APIs estén activas.
output "project_id" {
  description = "ID del proyecto creado"
  value       = google_project.project.project_id
  depends_on  = [google_project_service.services]
}

output "project_number" {
  description = "Número del proyecto creado"
  value       = google_project.project.number
  depends_on  = [google_project_service.services]
}
