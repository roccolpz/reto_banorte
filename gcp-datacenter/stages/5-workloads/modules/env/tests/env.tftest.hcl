mock_provider "google" {}

variables {
  env               = "dev"
  prefix            = "acme"
  app_project_id    = "acme-dev-app-ab12"
  data_project_id   = "acme-dev-data-ab12"
  hub_project_id    = "acme-common-net-hub-ab12"
  network_self_link = "https://www.googleapis.com/compute/v1/projects/acme-dev-net-host-ab12/global/networks/acme-dev-net-vpc"
  subnets = {
    "us-central1" = {
      self_link           = "https://www.googleapis.com/compute/v1/projects/acme-dev-net-host-ab12/regions/us-central1/subnetworks/acme-dev-net-app-usc1"
      pods_range_name     = "pods"
      services_range_name = "services"
    }
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
  secure_tag_key     = "tagKeys/2001"
  secure_tag_values  = { "gke-nodes" = "tagValues/1001", vm = "tagValues/1002" }
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

run "dev_sin_cluster_dr_ni_alertas_del_hub" {
  command = plan

  assert {
    condition     = output.gke_dr_cluster_name == null
    error_message = "dev no crea clúster DR: gke_dr_cluster_name es null."
  }

  assert {
    condition     = !contains(keys(module.observability.alert_policy_ids), "vpn_tunnel_down")
    error_message = "Solo prod crea la alerta de túneles VPN (P13)."
  }

  assert {
    condition     = !contains(keys(module.observability.alert_policy_ids), "sql_replica_lag")
    error_message = "Sin réplica DR no hay alerta de retraso de réplica."
  }

  assert {
    condition     = local.monitored_project_ids == ["acme-dev-data-ab12"]
    error_message = "dev solo agrega el proyecto de datos a su metrics scope; el hub va solo en prod (P13)."
  }

  assert {
    condition     = module.observability.uptime_check_id == null
    error_message = "Sin uptime_check_host no se crea uptime check."
  }
}

run "dev_tamanos_por_defecto" {
  command = plan

  assert {
    condition     = length(local.gke_node_pools) == 1 && local.gke_node_pools.default.machine_type == "e2-medium" && local.gke_node_pools.default.min_count == 1 && local.gke_node_pools.default.max_count == 2
    error_message = "dev usa un pool e2-medium de 1 a 2 nodos (R12)."
  }

  assert {
    condition     = local.sql_tier == "db-custom-1-3840"
    error_message = "dev usa Cloud SQL db-custom-1-3840 (R12)."
  }
}

run "etiquetas_seguras_en_nodos_y_vm" {
  command = plan

  assert {
    condition     = local.gke_tags == { "tagKeys/2001" = "tagValues/1001" }
    error_message = "Los nodos de GKE llevan la etiqueta segura gke-nodes."
  }

  assert {
    condition     = local.vm_tags == { "tagKeys/2001" = "tagValues/1002" }
    error_message = "Las VM del MIG llevan la etiqueta segura vm."
  }
}

run "uptime_imagen_y_tamanos_a_medida" {
  # apply con el proveedor simulado: el ID del uptime check solo se conoce después de crearlo.
  command = apply

  variables {
    uptime_check_host = "app.example.com"
    image_family      = "projects/acme-common-images-ab12/global/images/family/debian-12-cis"
    sql_tier          = "db-custom-4-15360"
    gke_node_pools    = { general = { machine_type = "e2-standard-4", min_count = 2, max_count = 5 } }
  }

  assert {
    condition     = module.observability.uptime_check_id != null
    error_message = "uptime_check_host crea el uptime check (R7)."
  }

  assert {
    condition     = local.sql_tier == "db-custom-4-15360" && local.gke_node_pools.general.max_count == 5
    error_message = "sql_tier y gke_node_pools explícitos reemplazan los del entorno (R12)."
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
    subnets = {
      "us-central1" = { self_link = "projects/h/regions/us-central1/subnetworks/app-usc1", pods_range_name = "pods", services_range_name = "services" }
      "us-east4"    = { self_link = "projects/h/regions/us-east4/subnetworks/app-use4", pods_range_name = "pods-use4", services_range_name = "services-use4" }
    }
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

  assert {
    condition     = output.gke_dr_cluster_name == "acme-prod-app-gke-dr" && module.gke_dr[0].location == "us-east4"
    error_message = "prod crea el clúster DR regional acme-prod-app-gke-dr en us-east4 (R11)."
  }

  assert {
    condition     = local.dr_master_cidr == "172.16.31.0/28"
    error_message = "El master del clúster DR usa 172.16.31.0/28 (contrato §5)."
  }

  assert {
    condition     = contains(keys(module.observability.alert_policy_ids), "vpn_tunnel_down") && contains(keys(module.observability.alert_policy_ids), "sql_replica_lag")
    error_message = "prod crea la alerta de túneles VPN y la de retraso de réplica."
  }

  assert {
    condition     = contains(local.monitored_project_ids, "acme-common-net-hub-ab12")
    error_message = "prod agrega el hub a su metrics scope para la alerta VPN."
  }

  assert {
    condition     = local.gke_node_pools.default.machine_type == "e2-standard-2" && local.sql_tier == "db-custom-2-7680"
    error_message = "prod usa nodos e2-standard-2 y Cloud SQL db-custom-2-7680 (R12)."
  }
}

run "prod_por_defecto_con_ha_dr_y_dual_region" {
  command = plan

  # Sin sql_ha, enable_dr_replica ni bucket_dual_region: así aplica el pipeline, que no pasa tfvars.
  variables {
    env = "prod"
    subnets = {
      "us-central1" = { self_link = "projects/h/regions/us-central1/subnetworks/app-usc1", pods_range_name = "pods", services_range_name = "services" }
      "us-east4"    = { self_link = "projects/h/regions/us-east4/subnetworks/app-use4", pods_range_name = "pods-use4", services_range_name = "services-use4" }
    }
    kms_keys = {
      storage      = "projects/s/locations/us-central1/keyRings/kr/cryptoKeys/storage"
      "storage-us" = "projects/s/locations/us/keyRings/kr-us/cryptoKeys/storage-us"
      sql          = "projects/s/locations/us-central1/keyRings/kr/cryptoKeys/sql"
      gke          = "projects/s/locations/us-central1/keyRings/kr/cryptoKeys/gke"
      "sql-dr"     = "projects/s/locations/us-east4/keyRings/kr-dr/cryptoKeys/sql-dr"
    }
  }

  assert {
    condition     = local.sql_ha && local.enable_dr_replica && local.bucket_dual_region && local.enable_dr_cluster
    error_message = "prod sin valores explícitos usa HA, réplica DR, bucket dual-region y clúster DR."
  }

  assert {
    condition     = module.sql.replica_name != null
    error_message = "prod crea la réplica DR por default."
  }
}

run "prod_sin_cluster_dr_explicito" {
  command = plan

  variables {
    env                = "prod"
    enable_dr_cluster  = false
    enable_dr_replica  = false
    bucket_dual_region = false
  }

  assert {
    condition     = output.gke_dr_cluster_name == null
    error_message = "enable_dr_cluster = false no crea el clúster DR."
  }
}

run "cluster_dr_sin_subred_dr" {
  command = plan

  variables {
    env                = "prod"
    enable_dr_replica  = false
    bucket_dual_region = false
  }

  expect_failures = [var.enable_dr_cluster]
}

run "region_primaria_sin_subred" {
  command = plan

  variables {
    primary_region = "us-east4"
  }

  expect_failures = [var.primary_region]
}

run "etiquetas_seguras_incompletas" {
  command = plan

  variables {
    secure_tag_values = { vm = "tagValues/1002" }
  }

  expect_failures = [var.secure_tag_values]
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
