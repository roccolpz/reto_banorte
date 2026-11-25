terraform {
  required_version = ">= 1.9"
  required_providers {
    google = { source = "hashicorp/google", version = "~> 6.0" }
  }
}

module "memorystore" {
  source = "../.."

  name       = "acme-prod-data-redis"
  project_id = "acme-prod-data-xxxx"
  network    = "projects/acme-prod-net-host-xxxx/global/networks/acme-prod-net-vpc"

  labels = {
    env         = "prod"
    app         = "landing-zone"
    owner       = "plataforma"
    cost_center = "TI-001"
    managed_by  = "terraform"
  }
}

output "host" {
  value = module.memorystore.host
}
