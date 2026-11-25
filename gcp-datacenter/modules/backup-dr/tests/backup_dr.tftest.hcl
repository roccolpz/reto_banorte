mock_provider "google" {
  mock_resource "google_backup_dr_backup_vault" {
    defaults = {
      service_account = "vault-123@gcp-sa-backupdr-pr.iam.gserviceaccount.com"
    }
  }
}

variables {
  name          = "acme-prod-data"
  project_id    = "acme-prod-data-ab12"
  sql_instances = { primary = "acme-prod-data-sql-ab12" }
  labels = {
    env = "prod", app = "landing-zone", owner = "plataforma", cost_center = "TI-001", managed_by = "terraform"
  }
}

run "diario_con_retencion_de_30_dias" {
  command = apply

  assert {
    condition     = google_backup_dr_backup_vault.this.backup_minimum_enforced_retention_duration == "2592000s"
    error_message = "La bóveda fuerza 30 días de retención."
  }

  assert {
    condition = (
      google_backup_dr_backup_plan.sql.backup_rules[0].standard_schedule[0].recurrence_type == "DAILY" &&
      google_backup_dr_backup_plan.sql.backup_rules[0].backup_retention_days == 30
    )
    error_message = "El plan es diario con 30 días de retención."
  }

  assert {
    condition     = google_backup_dr_backup_plan_association.sql["primary"].resource == "projects/acme-prod-data-ab12/instances/acme-prod-data-sql-ab12"
    error_message = "La instancia de Cloud SQL queda asociada al plan."
  }

  assert {
    condition     = google_project_iam_member.vault_sql.member == "serviceAccount:vault-123@gcp-sa-backupdr-pr.iam.gserviceaccount.com"
    error_message = "La cuenta de la bóveda recibe backupdr.cloudSqlOperator."
  }
}

run "rechaza_retencion_invalida" {
  command = plan

  variables {
    retention_days = 0
  }

  expect_failures = [var.retention_days]
}
