output "seed_project_id" {
  description = "ID del proyecto semilla"
  value       = module.seed_project.project_id
}

output "state_bucket" {
  description = "Nombre del bucket de estado de Terraform"
  value       = google_storage_bucket.state.name
}

output "state_kms_key" {
  description = "ID de la llave KMS que cifra el bucket de estado"
  value       = google_kms_crypto_key.state.id
}

output "stage_service_accounts" {
  description = "Correo de la SA de cada etapa: plan, 1-org, 2-security, 3-networks-{hub,dev,qa,prod}, 4-projects-{dev,qa,prod}, 5-workloads-{dev,qa,prod}, y la firmante attestor-prod (ADR 0022-k)"
  value       = { for k, sa in google_service_account.stage : k => sa.email }
}

output "wif_provider_name" {
  description = "Nombre completo del proveedor WIF (projects/<num>/locations/global/workloadIdentityPools/<pool>/providers/<prov>)"
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "bootstrap_folder_id" {
  description = "Carpeta bootstrap, en formato folders/<id>"
  value       = google_folder.bootstrap.name
}
