terraform {
  required_version = ">= 1.9.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  region = "us-central1"
}

resource "random_id" "suffix" {
  byte_length = 2
}

# GCP BUCKET CREATION
resource "google_storage_bucket" "tf_state" {
  name                        = "acme-tf-state-${random_id.suffix.hex}"
  location                    = "US"
  force_destroy               = false
  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }
}

output "bucket_name" {
  value = google_storage_bucket.tf_state.name
}