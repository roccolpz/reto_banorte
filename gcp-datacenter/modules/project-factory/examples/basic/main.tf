# Ejemplo mínimo: proyecto de aplicación de dev adjunto a la Shared VPC del entorno.
# Valores de ejemplo; no son IDs reales.
module "project" {
  source = "../.."

  name                       = "acme dev app"
  project_id                 = "acme-dev-app-a1b2"
  folder_id                  = "folders/000000000000"
  billing_account            = "000000-000000-000000"
  shared_vpc_host_project_id = "acme-dev-net-host-a1b2"
  activate_apis              = ["compute.googleapis.com", "container.googleapis.com"]

  labels = {
    env         = "dev"
    app         = "landing-zone"
    owner       = "plataforma"
    cost_center = "cc-0000"
    managed_by  = "terraform"
  }
}

output "project_id" {
  value = module.project.project_id
}
