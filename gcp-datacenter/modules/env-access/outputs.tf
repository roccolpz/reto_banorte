output "deployer_email" {
  description = "Correo de la cuenta de servicio de despliegue (se usará en el pipeline, punto B)"
  value       = google_service_account.deployer.email
}

output "deployer_name" {
  description = "Nombre completo del recurso, necesario para enlazar Workload Identity Federation"
  value       = google_service_account.deployer.name
}
