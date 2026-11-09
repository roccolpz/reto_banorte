output "project_id" {
  description = "ID del proyecto creado"
  value       = google_project.project.project_id
}

output "project_number" {
  description = "Número del proyecto creado"
  value       = google_project.project.number
}