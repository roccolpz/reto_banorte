resource "google_project" "project" {
  name            = var.name
  project_id      = var.project_id
  folder_id       = var.folder_id
  billing_account = var.billing_account
  labels          = var.labels
  deletion_policy = "DELETE"
}

# Habilitación dinámica de servicios/APIs
resource "google_project_service" "services" {
  for_each                   = toset(var.activate_apis)
  project                    = google_project.project.project_id
  service                    = each.key
  disable_on_destroy         = false
  disable_dependent_services = false
}

# Vinculación opcional a Shared VPC como Service Project
resource "google_compute_shared_vpc_service_project" "service_project" {
  count           = var.shared_vpc_host_project_id != "" ? 1 : 0
  host_project    = var.shared_vpc_host_project_id
  service_project = google_project.project.project_id

  depends_on = [google_project_service.services]
}