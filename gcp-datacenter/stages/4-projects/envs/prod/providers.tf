provider "google" {}

provider "google-beta" {}

# Access Context Manager exige proyecto de cuota: el común de seguridad, igual que en 2-security.
# Solo los recursos del perímetro usan este alias.
provider "google" {
  alias                 = "acm"
  billing_project       = local.security_project_id
  user_project_override = true
}
