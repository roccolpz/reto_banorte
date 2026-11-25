terraform {
  required_version = ">= 1.9"
  required_providers {
    google = { source = "hashicorp/google", version = "~> 6.0" }
  }
}

module "load_balancer" {
  source = "../.."

  name              = "acme-prod-app-lb"
  project_id        = "acme-prod-app-xxxx"
  cloud_run_service = "acme-prod-app-run"

  labels = {
    env         = "prod"
    app         = "landing-zone"
    owner       = "plataforma"
    cost_center = "TI-001"
    managed_by  = "terraform"
  }
}

output "ip_address" {
  value = module.load_balancer.ip_address
}
