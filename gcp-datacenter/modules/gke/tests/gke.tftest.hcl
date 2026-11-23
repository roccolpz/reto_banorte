mock_provider "google" {}

variables {
  cluster_name           = "acme-dev-gke"
  project_id             = "acme-dev-app-ab12"
  region                 = "us-central1"
  network                = "projects/acme-dev-net-host-ab12/global/networks/acme-dev-net-vpc"
  subnetwork             = "projects/acme-dev-net-host-ab12/regions/us-central1/subnetworks/acme-dev-net-app-usc1"
  master_ipv4_cidr_block = "172.16.10.0/28"
  node_pools = {
    general = { machine_type = "e2-standard-2", min_count = 1, max_count = 3 }
  }
  pods_range_name         = "pods"
  services_range_name     = "services"
  node_service_account    = "gke-nodes@acme-dev-app-ab12.iam.gserviceaccount.com"
  database_encryption_key = "projects/acme-common-security-ab12/locations/us-central1/keyRings/kr/cryptoKeys/gke"
  labels = {
    env = "dev", app = "landing-zone", owner = "plataforma", cost_center = "TI-001", managed_by = "terraform"
  }
}

run "zonal_por_defecto_con_pools_de_la_variable" {
  command = plan

  assert {
    condition     = google_container_cluster.primary.location == "us-central1-a"
    error_message = "Sin regional, el cluster debe ser zonal en la primera zona de la región."
  }

  assert {
    condition     = google_container_node_pool.pools["general"].node_config[0].machine_type == "e2-standard-2"
    error_message = "El pool debe usar machine_type de var.node_pools."
  }

  assert {
    condition     = google_container_node_pool.pools["general"].autoscaling[0].max_node_count == 3
    error_message = "El pool debe usar max_count de var.node_pools."
  }

  assert {
    condition     = google_container_node_pool.pools["general"].node_config[0].service_account == var.node_service_account
    error_message = "Los nodos deben usar la SA dedicada."
  }

  assert {
    condition     = google_container_cluster.primary.ip_allocation_policy[0].cluster_secondary_range_name == "pods"
    error_message = "El cluster debe usar el rango secundario de pods."
  }

  assert {
    condition     = google_container_cluster.primary.release_channel[0].channel == "REGULAR"
    error_message = "El canal de versiones por defecto es REGULAR."
  }

  assert {
    condition     = google_container_cluster.primary.binary_authorization[0].evaluation_mode == "PROJECT_SINGLETON_POLICY_ENFORCE"
    error_message = "Binary Authorization debe estar activo."
  }

  assert {
    condition     = google_container_cluster.primary.workload_identity_config[0].workload_pool == "acme-dev-app-ab12.svc.id.goog"
    error_message = "Workload Identity debe estar activo."
  }

  assert {
    condition     = google_container_cluster.primary.database_encryption[0].state == "ENCRYPTED"
    error_message = "Los secretos de etcd deben cifrarse con CMEK."
  }

  assert {
    condition     = google_container_cluster.primary.private_cluster_config[0].enable_private_nodes
    error_message = "Los nodos deben ser privados."
  }

  assert {
    condition     = google_container_cluster.primary.resource_labels["env"] == "dev"
    error_message = "El cluster debe llevar las etiquetas."
  }
}

run "regional_en_prod" {
  command = plan

  variables {
    regional = true
  }

  assert {
    condition     = google_container_cluster.primary.location == "us-central1"
    error_message = "Con regional = true la ubicación es la región."
  }

  assert {
    condition     = google_container_node_pool.pools["general"].location == "us-central1"
    error_message = "El pool sigue la ubicación del cluster."
  }
}

run "pools_con_etiquetas_seguras" {
  command = plan

  variables {
    resource_manager_tags = { "tagKeys/111" = "tagValues/222" }
  }

  assert {
    condition     = google_container_node_pool.pools["general"].node_config[0].resource_manager_tags["tagKeys/111"] == "tagValues/222"
    error_message = "Los nodos deben llevar la etiqueta segura que usan las reglas de firewall."
  }
}

run "rechaza_etiquetas_incompletas" {
  command = plan

  variables {
    labels = { env = "dev" }
  }

  expect_failures = [var.labels]
}

run "rechaza_cidr_de_master_invalido" {
  command = plan

  variables {
    master_ipv4_cidr_block = "no-es-cidr"
  }

  expect_failures = [var.master_ipv4_cidr_block]
}

run "rechaza_master_en_rango_on_prem" {
  command = plan

  variables {
    master_ipv4_cidr_block = "192.168.1.0/28"
  }

  expect_failures = [var.master_ipv4_cidr_block]
}

run "rechaza_sin_etiquetas" {
  command = plan

  variables {
    labels = {}
  }

  expect_failures = [var.labels]
}
