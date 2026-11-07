terraform {
  required_version = ">= 1.9.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
  backend "gcs" {
    bucket = "acme-tf-state-bucket"
    prefix = "stages/test-orchestration"
  }
}

provider "google" {
  region = var.primary_region
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
  source                 = "../../modules/gke"
  cluster_name           = "prod-basiquito-gke"
  project_id             = module.project_host_prod.project_id
  region                 = var.primary_region
  network                = module.network_prod.network_id
  subnetwork             = module.network_prod.subnet_id
  master_ipv4_cidr_block = "172.16.0.0/28"
  node_pools = {
    default = { machine_type = "e2-medium", min_count = 1, max_count = 3 }
  }
}

# Perímetro VPC-SC para Producción
module "vpCSC_prod" {
  source              = "../../modules/vpc-sc"
  parent_org_id       = var.org_id
  policy_name         = "PolicyProd_${var.suffix}"
  perimeter_name      = "prod_perimeter_${var.suffix}"
  restricted_services = ["storage.googleapis.com", "sqladmin.googleapis.com"]
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
  source                 = "../../modules/gke"
  cluster_name           = "dev-basiquito-gke"
  project_id             = module.project_host_dev.project_id
  region                 = var.primary_region
  network                = module.network_dev.network_id
  subnetwork             = module.network_dev.subnet_id
  master_ipv4_cidr_block = "172.16.10.0/28"
  node_pools = {
    default = { machine_type = "e2-medium", min_count = 1, max_count = 2 }
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
  source                 = "../../modules/gke"
  cluster_name           = "test-basiquito-gke"
  project_id             = module.project_host_test.project_id
  region                 = var.primary_region
  network                = module.network_test.network_id
  subnetwork             = module.network_test.subnet_id
  master_ipv4_cidr_block = "172.16.20.0/28"
  node_pools = {
    default = { machine_type = "e2-medium", min_count = 1, max_count = 2 }
  }
}

# Perímetro VPC-SC para Non-Production (Test)
module "vpCSC_nonprod" {
  source              = "../../modules/vpc-sc"
  parent_org_id       = var.org_id
  policy_name         = "PolicyNonProd_${var.suffix}"
  perimeter_name      = "nonprod_perimeter_${var.suffix}"
  restricted_services = ["storage.googleapis.com"]
  member_projects     = [module.project_host_test.project_number, module.project_host_dev.project_number]
}