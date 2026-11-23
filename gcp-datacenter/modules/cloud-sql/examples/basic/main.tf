terraform {
  required_version = ">= 1.9"
  required_providers {
    google = { source = "hashicorp/google", version = "~> 6.0" }
  }
}

module "cloud_sql" {
  source = "../.."

  name         = "acme-dev-data-pg"
  project_id   = "acme-dev-data-xxxx"
  network      = "projects/acme-dev-net-host-xxxx/global/networks/acme-dev-net-vpc"
  kms_key_name = "projects/acme-common-security-xxxx/locations/us-central1/keyRings/acme-dev-xxxx/cryptoKeys/sql"

  labels = {
    env         = "dev"
    app         = "landing-zone"
    owner       = "plataforma"
    cost_center = "TI-001"
    managed_by  = "terraform"
  }
}

output "private_ip" {
  value = module.cloud_sql.private_ip_address
}
