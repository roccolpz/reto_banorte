resource "google_redis_instance" "this" {
  name           = var.name
  project        = var.project_id
  region         = var.region
  tier           = var.tier
  memory_size_gb = var.memory_size_gb
  redis_version  = var.redis_version
  labels         = var.labels

  # IP privada por el acceso a servicios privados de la VPC compartida (el mismo rango que Cloud SQL).
  authorized_network = var.network
  connect_mode       = "PRIVATE_SERVICE_ACCESS"

  auth_enabled            = true
  transit_encryption_mode = "SERVER_AUTHENTICATION"
}
