terraform {
  required_version = ">= 1.9"
  required_providers {
    google = { source = "hashicorp/google", version = "~> 6.0" }
  }
}

module "kms_dev" {
  source = "../.."

  project_id   = "acme-common-security-ab12"
  location     = "us-central1"
  keyring_name = "acme-dev-keyring-ab12"
  labels = {
    env         = "dev"
    app         = "landing-zone"
    owner       = "platform"
    cost_center = "infra"
    managed_by  = "terraform"
  }
  keys = {
    storage = {
      # Agente de servicio de Cloud Storage del proyecto de datos.
      encrypter_decrypters = ["serviceAccount:service-111111111111@gs-project-accounts.iam.gserviceaccount.com"]
    }
    sql = {}
    gke = {}
  }
}

output "key_ids" {
  value = module.kms_dev.key_ids
}
