# Sink agregado de auditoría de toda la organización hacia un bucket con retención.

resource "google_storage_bucket" "audit" {
  project                     = module.common_project["logging"].project_id
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

resource "google_storage_bucket_iam_member" "audit_sink_writer" {
  bucket = google_storage_bucket.audit.name
  role   = "roles/storage.objectCreator"
  member = google_logging_organization_sink.audit.writer_identity
}
