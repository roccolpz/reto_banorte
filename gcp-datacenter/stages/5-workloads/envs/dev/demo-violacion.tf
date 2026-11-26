# PR de demostración (no se fusiona): bucket público que el pipeline debe bloquear.
resource "google_storage_bucket" "demo_publico" {
  project                     = local.projects.app_project_id
  name                        = "${var.prefix}-dev-demo-publico"
  location                    = "US"
  uniform_bucket_level_access = true
  public_access_prevention    = "inherited"
  labels                      = local.labels
}

resource "google_storage_bucket_iam_member" "demo_publico" {
  bucket = google_storage_bucket.demo_publico.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}
