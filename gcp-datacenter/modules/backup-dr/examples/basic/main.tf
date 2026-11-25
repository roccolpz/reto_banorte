terraform {
  required_version = ">= 1.9"
  required_providers {
    google = { source = "hashicorp/google", version = "~> 6.0" }
  }
}

module "backup_dr" {
  source = "../.."

  name          = "acme-prod-data"
  project_id    = "acme-prod-data-xxxx"
  sql_instances = { primary = "acme-prod-data-sql-xxxx" }

  labels = {
    env         = "prod"
    app         = "landing-zone"
    owner       = "plataforma"
    cost_center = "TI-001"
    managed_by  = "terraform"
  }
}

output "vault_id" {
  value = module.backup_dr.vault_id
}
