terraform {
  required_version = ">= 1.9"
  required_providers {
    google = { source = "hashicorp/google", version = "~> 6.0" }
  }
}

module "mig" {
  source = "../.."

  name                  = "acme-dev-app-probe"
  project_id            = "acme-dev-app-xxxx"
  subnetwork            = "projects/acme-dev-net-host-xxxx/regions/us-central1/subnetworks/acme-dev-net-app-usc1"
  service_account_email = "acme-dev-vm@acme-dev-app-xxxx.iam.gserviceaccount.com"

  labels = {
    env         = "dev"
    app         = "landing-zone"
    owner       = "plataforma"
    cost_center = "TI-001"
    managed_by  = "terraform"
  }
}

output "mig_name" {
  value = module.mig.mig_name
}
