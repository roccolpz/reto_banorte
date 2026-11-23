terraform {
  required_version = ">= 1.9.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
  backend "local" {
    path = "terraform.tfstate"
    #bucket = "acme-tf-state-6e95"
    #prefix = "stages/test-orchestration"
  }
}

provider "google" {
  region = var.primary_region
}

# 1. Creamos la política global una sola vez para toda la organización
resource "google_access_context_manager_access_policy" "main" {
  parent = "organizations/544577283167"
  title  = "Global_Policy_Demo01"
}

# ==========================================
# 1. ENTORNO PROD (Host Project + GKE + VPC-SC)
# ==========================================

module "project_host_prod" {
  source          = "../../modules/project-factory"
  name            = "Prod VPC Host"
  project_id      = "acme-host-prod-${var.suffix}"
  folder_id       = var.prod_folder_id
  billing_account = var.billing_account
  activate_apis   = ["compute.googleapis.com", "container.googleapis.com"]
}

module "network_prod" {
  source       = "../../modules/network-host"
  network_name = "acme-prod-shared-vpc"
  project_id   = module.project_host_prod.project_id
  subnet_cidr  = "10.30.0.0/16"
  region       = var.primary_region
}

module "gke_prod" {
  source                     = "../../modules/gke"
  cluster_name               = "prod-basiquito-gke"
  project_id                 = module.project_host_prod.project_id
  region                     = var.primary_region
  network                    = module.network_prod.network_id
  subnetwork                 = module.network_prod.subnet_id
  master_ipv4_cidr_block     = "172.16.100.0/28"
  master_authorized_networks = var.master_authorized_networks
  node_pools = {
    default = { machine_type = "e2-micro", min_count = 1, max_count = 1 }
  }
}

# Perímetro VPC-SC para Producción
module "vpCSC_prod" {
  source              = "../../modules/vpc-sc"
  perimeter_name      = "PolicyProd_demo01"
  access_policy_name  = google_access_context_manager_access_policy.main.name
  restricted_services = ["storage.googleapis.com"] # o los servicios que requieras
  member_projects     = [module.project_host_prod.project_number]
}


# ==========================================
# 2. ENTORNO NON-PROD: DEV (Project Factory duplicado)
# ==========================================

module "project_host_dev" {
  source          = "../../modules/project-factory"
  name            = "Dev VPC Host"
  project_id      = "acme-host-dev-${var.suffix}"
  folder_id       = var.dev_folder_id
  billing_account = var.billing_account
  activate_apis   = ["compute.googleapis.com", "container.googleapis.com"]
}

module "network_dev" {
  source       = "../../modules/network-host"
  network_name = "acme-dev-shared-vpc"
  project_id   = module.project_host_dev.project_id
  subnet_cidr  = "10.10.0.0/16"
  region       = var.primary_region
}

module "gke_dev" {
  source                     = "../../modules/gke"
  cluster_name               = "dev-basiquito-gke"
  project_id                 = module.project_host_dev.project_id
  region                     = var.primary_region
  network                    = module.network_dev.network_id
  subnetwork                 = module.network_dev.subnet_id
  master_ipv4_cidr_block     = "172.16.110.0/28"
  master_authorized_networks = var.master_authorized_networks
  node_pools = {
    default = { machine_type = "e2-micro", min_count = 1, max_count = 1 }
  }
}


# ==========================================
# 3. ENTORNO NON-PROD: TEST (Project Factory duplicado + VPC-SC Non-Prod)
# ==========================================

module "project_host_test" {
  source          = "../../modules/project-factory"
  name            = "Test VPC Host"
  project_id      = "acme-host-test-${var.suffix}"
  folder_id       = var.dev_folder_id # O carpeta de pruebas
  billing_account = var.billing_account
  activate_apis   = ["compute.googleapis.com", "container.googleapis.com"]
}

module "network_test" {
  source       = "../../modules/network-host"
  network_name = "acme-test-shared-vpc"
  project_id   = module.project_host_test.project_id
  subnet_cidr  = "10.20.0.0/16"
  region       = var.primary_region
}

module "gke_test" {
  source                     = "../../modules/gke"
  cluster_name               = "test-basiquito-gke"
  project_id                 = module.project_host_test.project_id
  region                     = var.primary_region
  network                    = module.network_test.network_id
  subnetwork                 = module.network_test.subnet_id
  master_ipv4_cidr_block     = "172.16.120.0/28"
  master_authorized_networks = var.master_authorized_networks
  node_pools = {
    default = { machine_type = "e2-micro", min_count = 1, max_count = 1 }
  }
}

# Perímetro VPC-SC para Non-Production (Test)
module "vpCSC_nonprod" {
  source              = "../../modules/vpc-sc"
  perimeter_name      = "PolicyNonProd_demo01"
  access_policy_name  = google_access_context_manager_access_policy.main.name
  restricted_services = ["storage.googleapis.com"]
  member_projects     = [module.project_host_dev.project_number, module.project_host_test.project_number]
}