terraform {
  required_version = ">= 1.9"
  required_providers {
    google = { source = "hashicorp/google", version = "~> 6.0" }
  }
}

module "cloud_run" {
  source = "../.."

  name                  = "acme-dev-app-run"
  project_id            = "acme-dev-app-xxxx"
  service_account_email = "cloud-run@acme-dev-app-xxxx.iam.gserviceaccount.com"

  labels = {
    env         = "dev"
    app         = "landing-zone"
    owner       = "plataforma"
    cost_center = "TI-001"
    managed_by  = "terraform"
  }
}

output "service_name" {
  value = module.cloud_run.service_name
}
