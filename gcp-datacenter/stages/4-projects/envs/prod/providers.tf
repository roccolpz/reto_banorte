provider "google" {}

provider "google-beta" {}

# Access Context Manager exige proyecto de cuota: la semilla, donde 0-bootstrap da serviceUsageConsumer a todas las SAs de etapa (igual que 1-org).
# Solo los recursos del perímetro usan este alias.
provider "google" {
  alias                 = "acm"
  billing_project       = data.terraform_remote_state.bootstrap.outputs.seed_project_id
  user_project_override = true
}
