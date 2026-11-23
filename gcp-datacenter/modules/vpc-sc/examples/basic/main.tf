terraform {
  required_version = ">= 1.9"
  required_providers {
    google = { source = "hashicorp/google", version = "~> 6.0" }
  }
}

# Perímetro de dev en dry-run (default), con ingreso para la SA de plan y egreso de la app al proyecto de respaldo.
module "perimeter_dev" {
  source = "../.."

  perimeter_name      = "acme_dev_perimeter"
  access_policy_name  = "123456789"
  restricted_services = ["storage.googleapis.com", "sqladmin.googleapis.com", "bigquery.googleapis.com"]
  ingress_identities  = ["serviceAccount:sa-tf-plan@acme-bootstrap-seed-ab12.iam.gserviceaccount.com"]
  egress_rules = [{
    identities = ["serviceAccount:app-workload@acme-dev-app-ab12.iam.gserviceaccount.com"]
    resources  = ["projects/222222222222"]
    services   = ["storage.googleapis.com"]
  }]
}

# Así agrega 4-projects un proyecto al perímetro en dry-run (con enforce = true se usa
# google_access_context_manager_service_perimeter_resource).
resource "google_access_context_manager_service_perimeter_dry_run_resource" "app" {
  perimeter_name = module.perimeter_dev.name
  resource       = "projects/111111111111"
}

output "perimeter_name" {
  value = module.perimeter_dev.name
}
