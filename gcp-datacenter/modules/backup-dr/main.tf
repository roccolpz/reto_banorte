locals {
  retention = "${var.retention_days * 86400}s"
}

resource "google_backup_dr_backup_vault" "this" {
  backup_vault_id                            = "${var.name}-vault"
  project                                    = var.project_id
  location                                   = var.region
  description                                = "Bóveda de respaldos ${var.name}"
  backup_minimum_enforced_retention_duration = local.retention
  labels                                     = var.labels

  # Permite destruir la bóveda cuando ya no tiene respaldos activos (destroy de la organización de prueba).
  ignore_inactive_datasources   = true
  ignore_backup_plan_references = true
}

resource "google_backup_dr_backup_plan" "sql" {
  backup_plan_id = "${var.name}-sql-daily"
  project        = var.project_id
  location       = var.region
  resource_type  = "sqladmin.googleapis.com/Instance"
  backup_vault   = google_backup_dr_backup_vault.this.id
  description    = "Respaldo diario de Cloud SQL, ${var.retention_days} días"
  # La API exige log_retention_days < backup_retention_days de la regla diaria.
  log_retention_days = var.log_retention_days

  backup_rules {
    rule_id               = "daily"
    backup_retention_days = var.retention_days

    standard_schedule {
      recurrence_type = "DAILY"
      time_zone       = var.time_zone

      backup_window {
        start_hour_of_day = var.backup_window_start_hour
        # La API exige una ventana de al menos 6 horas para respaldos diarios.
        end_hour_of_day = var.backup_window_start_hour + 6
      }
    }
  }
}

# La cuenta de servicio de la bóveda lee y respalda las instancias de Cloud SQL del proyecto.
resource "google_project_iam_member" "vault_sql" {
  project = var.project_id
  role    = "roles/backupdr.cloudSqlOperator"
  member  = "serviceAccount:${google_backup_dr_backup_vault.this.service_account}"
}

resource "google_backup_dr_backup_plan_association" "sql" {
  for_each = var.sql_instances

  backup_plan_association_id = "${each.key}-bpa"
  project                    = var.project_id
  location                   = var.region
  resource_type              = "sqladmin.googleapis.com/Instance"
  resource                   = "projects/${var.project_id}/instances/${each.value}"
  backup_plan                = google_backup_dr_backup_plan.sql.name

  depends_on = [google_project_iam_member.vault_sql]
}
