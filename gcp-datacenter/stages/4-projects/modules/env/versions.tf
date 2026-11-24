terraform {
  required_version = ">= 1.9"
  required_providers {
    google = {
      source                = "hashicorp/google"
      version               = ">= 6.0, < 7.0"
      configuration_aliases = [google.acm]
    }
    google-beta = { source = "hashicorp/google-beta", version = ">= 6.0, < 7.0" }
  }
}
