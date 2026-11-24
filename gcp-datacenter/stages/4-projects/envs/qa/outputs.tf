output "app_project_id" {
  description = "ID del proyecto de aplicación."
  value       = module.env.app_project_id
}

output "app_project_number" {
  description = "Número del proyecto de aplicación."
  value       = module.env.app_project_number
}

output "data_project_id" {
  description = "ID del proyecto de datos."
  value       = module.env.data_project_id
}

output "data_project_number" {
  description = "Número del proyecto de datos."
  value       = module.env.data_project_number
}

output "service_accounts" {
  description = "Cuentas de servicio de cargas: gke_nodes, app_workload, vm → email."
  value       = module.env.service_accounts
}
