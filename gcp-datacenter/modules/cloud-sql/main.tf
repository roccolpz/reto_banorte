locals {
  ip_configuration = {
    ipv4_enabled    = false
    private_network = var.network
    ssl_mode        = "ENCRYPTED_ONLY"
  }
}

resource "google_sql_database_instance" "primary" {
  name                = var.name
  project             = var.project_id
  region              = var.region
  database_version    = var.database_version
  encryption_key_name = var.kms_key_name
  deletion_protection = var.deletion_protection

  settings {
    tier                        = var.tier
    edition                     = "ENTERPRISE"
    availability_type           = var.ha ? "REGIONAL" : "ZONAL"
    disk_type                   = "PD_SSD"
    disk_size                   = var.disk_size_gb
    disk_autoresize             = true
    deletion_protection_enabled = var.deletion_protection
    user_labels                 = var.labels

    ip_configuration {
      ipv4_enabled    = local.ip_configuration.ipv4_enabled
      private_network = local.ip_configuration.private_network
      ssl_mode        = local.ip_configuration.ssl_mode
    }

    database_flags {
      name  = "cloudsql.iam_authentication"
      value = "on"
    }

    backup_configuration {
      enabled                        = true
      start_time                     = var.backup_start_time
      point_in_time_recovery_enabled = true
      transaction_log_retention_days = var.transaction_log_retention_days

      backup_retention_settings {
        retained_backups = var.retained_backups
      }
    }
  }

  # El disco crece con disk_autoresize; no volver a reducirlo.
  lifecycle {
    ignore_changes = [settings[0].disk_size]
  }
}

resource "google_sql_database_instance" "replica" {
  count = var.enable_dr_replica ? 1 : 0

  name                 = "${var.name}-dr"
  project              = var.project_id
  region               = var.dr_region
  database_version     = var.database_version
  master_instance_name = google_sql_database_instance.primary.name
  encryption_key_name  = var.dr_kms_key_name
  deletion_protection  = var.deletion_protection

  settings {
    tier                        = var.tier
    edition                     = "ENTERPRISE"
    availability_type           = "ZONAL"
    disk_type                   = "PD_SSD"
    disk_autoresize             = true
    deletion_protection_enabled = var.deletion_protection
    user_labels                 = var.labels

    ip_configuration {
      ipv4_enabled    = local.ip_configuration.ipv4_enabled
      private_network = local.ip_configuration.private_network
      ssl_mode        = local.ip_configuration.ssl_mode
    }

    database_flags {
      name  = "cloudsql.iam_authentication"
      value = "on"
    }
  }
}
