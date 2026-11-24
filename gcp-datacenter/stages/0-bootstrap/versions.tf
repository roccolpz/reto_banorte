terraform {
  required_version = ">= 1.9"
  required_providers {
    google      = { source = "hashicorp/google", version = "~> 6.0" }
    google-beta = { source = "hashicorp/google-beta", version = "~> 6.0" }
    random      = { source = "hashicorp/random", version = "~> 3.6" }
  }
}

# Primer apply con backend local (el bucket aún no existe). Después se migra a GCS:
# ver "Migración del estado" en README.md.
provider "google" {
  region = var.region
}
