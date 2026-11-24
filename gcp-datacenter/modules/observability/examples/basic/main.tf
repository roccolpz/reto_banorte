terraform {
  required_version = ">= 1.9"
  required_providers {
    google = { source = "hashicorp/google", version = "~> 6.0" }
  }
}

module "observability" {
  source = "../.."

  project_id            = "acme-dev-app-xxxx"
  name_prefix           = "acme-dev"
  notification_email    = "noc@example.com"
  monitored_project_ids = ["acme-dev-data-xxxx", "acme-common-net-hub-xxxx"]

  labels = {
    env         = "dev"
    app         = "landing-zone"
    owner       = "plataforma"
    cost_center = "TI-001"
    managed_by  = "terraform"
  }
}

output "alert_policy_ids" {
  value = module.observability.alert_policy_ids
}
