output "vault_id" {
  description = "ID de la bóveda de respaldos."
  value       = google_backup_dr_backup_vault.this.id
}

output "backup_plan_id" {
  description = "ID del plan de respaldo de Cloud SQL."
  value       = google_backup_dr_backup_plan.sql.id
}
