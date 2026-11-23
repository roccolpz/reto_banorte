terraform {
  required_version = ">= 1.9"
  required_providers {
    google      = { source = "hashicorp/google", version = "~> 6.0" }
    google-beta = { source = "hashicorp/google-beta", version = "~> 6.0" }
    random      = { source = "hashicorp/random", version = "~> 3.6" }
  }
}

# Org policies y la API de Resource Manager exigen un proyecto de cuota: se usa la semilla.
provider "google" {
  region                = var.region
  billing_project       = data.terraform_remote_state.bootstrap.outputs.seed_project_id
  user_project_override = true
}
