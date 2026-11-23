terraform {
  required_version = ">= 1.9"
  required_providers {
    google = { source = "hashicorp/google", version = "~> 6.0" }
  }
}

module "storage" {
  source = "../.."

  name         = "acme-dev-data-files-xxxx"
  project_id   = "acme-dev-data-xxxx"
  kms_key_name = "projects/acme-common-security-xxxx/locations/us-central1/keyRings/acme-dev-xxxx/cryptoKeys/storage"

  labels = {
    env         = "dev"
    app         = "landing-zone"
    owner       = "plataforma"
    cost_center = "TI-001"
    managed_by  = "terraform"
  }
}

output "bucket_name" {
  value = module.storage.bucket_name
}
