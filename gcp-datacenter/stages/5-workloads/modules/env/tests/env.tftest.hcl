mock_provider "google" {}

variables {
  env               = "dev"
  prefix            = "acme"
  app_project_id    = "acme-dev-app-ab12"
  data_project_id   = "acme-dev-data-ab12"
  hub_project_id    = "acme-common-net-hub-ab12"
  network_self_link = "https://www.googleapis.com/compute/v1/projects/acme-dev-net-host-ab12/global/networks/acme-dev-net-vpc"
  subnet = {
    self_link           = "https://www.googleapis.com/compute/v1/projects/acme-dev-net-host-ab12/regions/us-central1/subnetworks/acme-dev-net-app-usc1"
    pods_range_name     = "pods"
    services_range_name = "services"
  }
  service_accounts = {
    gke_nodes    = "gke-nodes@acme-dev-app-ab12.iam.gserviceaccount.com"
    app_workload = "app-workload@acme-dev-app-ab12.iam.gserviceaccount.com"
    vm           = "vm-instances@acme-dev-app-ab12.iam.gserviceaccount.com"
  }
  kms_keys = {
    storage = "projects/acme-common-security-ab12/locations/us-central1/keyRings/kr/cryptoKeys/storage"
    sql     = "projects/acme-common-security-ab12/locations/us-central1/keyRings/kr/cryptoKeys/sql"
    gke     = "projects/acme-common-security-ab12/locations/us-central1/keyRings/kr/cryptoKeys/gke"
  }
  notification_email = "noc@example.com"
  labels             = { app = "landing-zone", owner = "platform", cost_center = "infra", env = "dev", managed_by = "terraform" }
}

run "dev_zonal_sin_ha" {
  command = plan

  assert {
    condition     = output.gke_cluster_name == "acme-dev-app-gke" && module.gke.location == "us-central1-a"
    error_message = "dev usa un clúster zonal acme-dev-app-gke."
  }

  assert {
    condition     = output.bucket_name == "acme-dev-data-ab12-app"
    error_message = "El bucket se nombra con el ID del proyecto de datos."
  }

  assert {
    condition     = module.sql.replica_name == null
    error_message = "dev no crea réplica DR por default."
  }

  assert {
    condition     = google_service_account_iam_member.workload_identity.member == "serviceAccount:acme-dev-app-ab12.svc.id.goog[app/app]"
    error_message = "La KSA app/app se vincula a app_workload por Workload Identity."
  }

  assert {
    condition     = google_storage_bucket_iam_member.app_workload.role == "roles/storage.objectUser"
    error_message = "app_workload recibe storage.objectUser en el bucket."
  }

  assert {
    condition     = output.mig_name == "acme-dev-app-mig"
    error_message = "MIG con el patrón <prefix>-<env>-app-mig."
  }
}

run "prod_regional_ha_dr" {
  command = plan

  variables {
    env                = "prod"
    regional           = true
    sql_ha             = true
    enable_dr_replica  = true
    bucket_dual_region = true
    kms_keys = {
      storage      = "projects/s/locations/us-central1/keyRings/kr/cryptoKeys/storage"
      "storage-us" = "projects/s/locations/us/keyRings/kr-us/cryptoKeys/storage-us"
      sql          = "projects/s/locations/us-central1/keyRings/kr/cryptoKeys/sql"
      gke          = "projects/s/locations/us-central1/keyRings/kr/cryptoKeys/gke"
      "sql-dr"     = "projects/s/locations/us-east4/keyRings/kr-dr/cryptoKeys/sql-dr"
    }
  }

  assert {
    condition     = module.gke.location == "us-central1"
    error_message = "prod con regional = true usa un clúster regional."
  }

  assert {
    condition     = module.sql.replica_name != null
    error_message = "prod con enable_dr_replica crea la réplica."
  }
}

run "dual_region_sin_llave_us" {
  command = plan

  variables {
    bucket_dual_region = true
  }

  expect_failures = [var.bucket_dual_region]
}

run "entorno_invalido" {
  command = plan

  variables {
    env = "test"
  }

  expect_failures = [var.env]
}
