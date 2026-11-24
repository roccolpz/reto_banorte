output "folder_ids" {
  description = "Carpetas bootstrap, common, dev, qa y prod, en formato folders/<id>"
  value = merge(
    { bootstrap = data.terraform_remote_state.bootstrap.outputs.bootstrap_folder_id },
    { for k, f in google_folder.this : k => f.name },
  )
}

output "common_project_ids" {
  description = "Proyectos de common: net_hub, logging, security y backup"
  value       = local.common_project_ids
}

output "net_host_project_ids" {
  description = "Proyecto de red por entorno (dev, qa, prod). 3-networks los habilita como host de Shared VPC."
  value       = { for e, p in module.net_host_project : e => p.project_id }
}

output "audit_log_bucket" {
  description = "Bucket de auditoría que recibe el sink agregado de la organización"
  value       = google_storage_bucket.audit.name
}

output "common_project_numbers" {
  description = "Número de cada proyecto de common (net_hub, logging, security, backup). 2-security lo usa como destino de egreso de VPC-SC."
  value       = local.common_project_numbers
}

output "custom_role_ids" {
  description = "Roles a medida de la organización: kms_key_iam_admin y tag_value_iam_admin, en formato organizations/<id>/roles/<nombre>"
  value       = local.custom_role_ids
  depends_on  = [google_organization_iam_custom_role.this]
}

output "compact_projects" {
  description = "true si app y datos viven en el proyecto del entorno (4-projects no crea proyectos)"
  value       = var.compact_projects
}
