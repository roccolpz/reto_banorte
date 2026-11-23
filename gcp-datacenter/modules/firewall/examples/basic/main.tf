provider "google" {}

module "firewall" {
  source = "../.."

  project_id  = "acme-dev-net-host-0000"
  network     = "https://www.googleapis.com/compute/v1/projects/acme-dev-net-host-0000/global/networks/acme-dev-net-vpc"
  name_prefix = "acme-dev-net"
  secure_tags = ["gke-nodes", "vm"]

  rules = {
    deny-other-envs = {
      description    = "Aislamiento lateral: niega tráfico desde otros entornos."
      action         = "deny"
      priority       = 900
      ranges         = ["10.20.0.0/16", "10.30.0.0/16", "10.31.0.0/16"]
      enable_logging = true
    }
    allow-internal = {
      description = "Tráfico interno del entorno hacia las cargas etiquetadas."
      priority    = 1000
      ranges      = ["10.10.0.0/16"]
      target_tags = ["gke-nodes", "vm"]
    }
    deny-all-ingress = {
      description    = "Niega todo el ingreso no permitido explícitamente."
      action         = "deny"
      priority       = 65000
      ranges         = ["0.0.0.0/0"]
      enable_logging = true
    }
  }
}
