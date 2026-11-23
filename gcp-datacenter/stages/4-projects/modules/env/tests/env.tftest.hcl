mock_provider "google" {}
mock_provider "google" {
  alias = "acm"
}
mock_provider "google-beta" {}

variables {
  env             = "prod"
  prefix          = "acme"
  suffix          = "ab12"
  billing_account = "000000-000000-000000"
  folder_id       = "folders/111111111111"
  host_project_id = "acme-prod-net-host-ab12"
  subnets = {
    "us-central1" = { name = "acme-prod-net-app-usc1", self_link = "projects/acme-prod-net-host-ab12/regions/us-central1/subnetworks/acme-prod-net-app-usc1" }
    "us-east4"    = { name = "acme-prod-net-app-use4", self_link = "projects/acme-prod-net-host-ab12/regions/us-east4/subnetworks/acme-prod-net-app-use4" }
  }
  kms_keys = {
    storage  = "projects/acme-common-security-ab12/locations/us-central1/keyRings/kr/cryptoKeys/storage"
    sql      = "projects/acme-common-security-ab12/locations/us-central1/keyRings/kr/cryptoKeys/sql"
    gke      = "projects/acme-common-security-ab12/locations/us-central1/keyRings/kr/cryptoKeys/gke"
    "sql-dr" = "projects/acme-common-security-ab12/locations/us-east4/keyRings/kr-dr/cryptoKeys/sql-dr"
  }
  perimeter_name           = "accessPolicies/123456789/servicePerimeters/acme_prod"
  deployer_service_account = "sa-tf-5-wl-prod@seed.iam.gserviceaccount.com"
  labels                   = { app = "landing-zone", owner = "platform", cost_center = "infra", env = "prod", managed_by = "terraform" }
}

run "proyectos_iam_y_perimetro_dry_run" {
  command = plan

  assert {
    condition     = output.app_project_id == "acme-prod-app-ab12" && output.data_project_id == "acme-prod-data-ab12"
    error_message = "Proyectos con el patrón <prefix>-<env>-<dominio>-<suffix>."
  }

  assert {
    condition     = keys(output.service_accounts) == ["app_workload", "gke_nodes", "vm"]
    error_message = "service_accounts debe tener gke_nodes, app_workload y vm."
  }

  assert {
    condition     = keys(google_kms_crypto_key_iam_member.service_agents) == ["gke", "sql", "sql-dr", "storage"]
    error_message = "Cada llave de kms_keys[env] recibe un agente de servicio."
  }

  assert {
    condition     = alltrue([for m in google_kms_crypto_key_iam_member.service_agents : m.role == "roles/cloudkms.cryptoKeyEncrypterDecrypter"])
    error_message = "Los agentes solo reciben cryptoKeyEncrypterDecrypter."
  }

  assert {
    condition     = length(google_compute_subnetwork_iam_member.network_users) == 4
    error_message = "Robot de GKE y cloudservices reciben networkUser en cada subred (2 x 2)."
  }

  assert {
    condition     = length(google_access_context_manager_service_perimeter_dry_run_resource.projects) == 2 && length(google_access_context_manager_service_perimeter_resource.projects) == 0
    error_message = "Con vpc_sc_enforce = false los proyectos entran al spec dry-run."
  }

  assert {
    condition     = google_project_iam_member.workload_roles["app_workload/data/roles/cloudsql.client"].project == "acme-prod-data-ab12"
    error_message = "app_workload recibe cloudsql.client en el proyecto de datos."
  }
}

run "perimetro_aplicado" {
  command = plan

  variables {
    vpc_sc_enforce = true
  }

  assert {
    condition     = length(google_access_context_manager_service_perimeter_resource.projects) == 2 && length(google_access_context_manager_service_perimeter_dry_run_resource.projects) == 0
    error_message = "Con vpc_sc_enforce = true los proyectos entran al status aplicado."
  }
}

run "sin_deployer" {
  command = plan

  variables {
    deployer_service_account = null
  }

  assert {
    condition     = length(google_project_iam_member.deployer) == 0 && length(google_service_account_iam_member.deployer) == 0
    error_message = "Sin deployer_service_account no hay permisos para la SA de 5-workloads."
  }
}

run "entorno_invalido" {
  command = plan

  variables {
    env = "test"
  }

  expect_failures = [var.env]
}
