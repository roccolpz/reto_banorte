output "app_project_id" {
  description = "ID del proyecto de aplicación."
  value       = module.app.project_id
}

output "app_project_number" {
  description = "Número del proyecto de aplicación."
  value       = module.app.project_number
}

output "data_project_id" {
  description = "ID del proyecto de datos."
  value       = module.data.project_id
}

output "data_project_number" {
  description = "Número del proyecto de datos."
  value       = module.data.project_number
}

output "service_accounts" {
  description = "Cuentas de servicio de cargas: gke_nodes, app_workload, vm → email."
  value       = { for k, sa in google_service_account.workloads : k => sa.email }
}
