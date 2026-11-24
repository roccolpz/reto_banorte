terraform {
  required_version = ">= 1.9"
  required_providers {
    google = { source = "hashicorp/google", version = "~> 6.0" }
  }
}

module "gke" {
  source = "../.."

  cluster_name           = "acme-dev-app-gke"
  project_id             = "acme-dev-app-xxxx"
  region                 = "us-central1"
  network                = "projects/acme-dev-net-host-xxxx/global/networks/acme-dev-net-vpc"
  subnetwork             = "projects/acme-dev-net-host-xxxx/regions/us-central1/subnetworks/acme-dev-net-app-usc1"
  pods_range_name        = "pods"
  services_range_name    = "services"
  master_ipv4_cidr_block = "172.16.10.0/28"
  node_service_account   = "acme-dev-gke-nodes@acme-dev-app-xxxx.iam.gserviceaccount.com"

  node_pools = {
    general = { machine_type = "e2-standard-2", min_count = 1, max_count = 3 }
  }

  labels = {
    env         = "dev"
    app         = "landing-zone"
    owner       = "plataforma"
    cost_center = "TI-001"
    managed_by  = "terraform"
  }
}

output "cluster_name" {
  value = module.gke.cluster_name
}
