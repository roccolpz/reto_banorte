# Sink agregado de auditoría de toda la organización hacia un bucket con retención.

resource "google_storage_bucket" "audit" {
  project                     = local.common_project_ids["logging"]
  name                        = "${var.prefix}-common-logging-audit-${var.suffix}"
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false
  labels                      = merge(local.labels, { env = "common" })

  retention_policy {
    retention_period = var.audit_retention_days * 86400
    # IRREVERSIBLE si es true (ver CONTRATO §8).
    is_locked = var.audit_retention_locked
  }
}

resource "google_logging_organization_sink" "audit" {
  name             = "${var.prefix}-org-audit-sink"
  org_id           = var.org_id
  destination      = "storage.googleapis.com/${google_storage_bucket.audit.name}"
  include_children = true
  filter           = "logName:\"cloudaudit.googleapis.com\""
}

# Data Access audit logs de escritura en toda la organización (Admin Activity siempre está activo). Sin DATA_READ:
# GKE y Cloud SQL generan mucho volumen de lecturas y el costo no se justifica en esta entrega.
resource "google_organization_iam_audit_config" "all" {
  org_id  = var.org_id
  service = "allServices"

  audit_log_config {
    log_type = "ADMIN_READ"
  }
  audit_log_config {
    log_type = "DATA_WRITE"
  }
}

resource "google_storage_bucket_iam_member" "audit_sink_writer" {
  bucket = google_storage_bucket.audit.name
  role   = "roles/storage.objectCreator"
  member = google_logging_organization_sink.audit.writer_identity
}
