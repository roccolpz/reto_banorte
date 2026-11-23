output "folder_ids" {
  description = "Carpetas bootstrap, common, dev, qa y prod, en formato folders/<id>"
  value = merge(
    { bootstrap = data.terraform_remote_state.bootstrap.outputs.bootstrap_folder_id },
    { for k, f in google_folder.this : k => f.name },
  )
}

output "common_project_ids" {
  description = "Proyectos de common: net_hub, logging, security y backup"
  value       = { for k, p in module.common_project : k => p.project_id }
}

output "net_host_project_ids" {
  description = "Proyecto de red por entorno (dev, qa, prod). 3-networks los habilita como host de Shared VPC."
  value       = { for e, p in module.net_host_project : e => p.project_id }
}

output "audit_log_bucket" {
  description = "Bucket de auditoría que recibe el sink agregado de la organización"
  value       = google_storage_bucket.audit.name
}
