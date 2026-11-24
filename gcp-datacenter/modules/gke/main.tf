locals {
  # shortcut: asume que la zona "-a" existe en la región (cierto en us-central1 y us-east4); agregar una variable de zona si se usa otra región.
  location = var.regional ? var.region : "${var.region}-a"

  # La SA dedicada es obligatoria: el acceso lo limita IAM, no los scopes.
  oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
}

resource "google_container_cluster" "primary" {
  name                     = var.cluster_name
  project                  = var.project_id
  location                 = local.location
  network                  = var.network
  subnetwork               = var.subnetwork
  deletion_protection      = var.deletion_protection
  remove_default_node_pool = true
  initial_node_count       = 1
  enable_shielded_nodes    = var.enable_shielded_nodes
  resource_labels          = var.labels

  # Dataplane V2 aplica las NetworkPolicy de Kubernetes (Cilium); el bloque network_policy queda apagado porque
  # Calico no se usa con ADVANCED_DATAPATH. Intranode visibility manda el tráfico entre pods del mismo nodo por la
  # VPC, para que lo vean los flow logs y las reglas de firewall.
  datapath_provider           = "ADVANCED_DATAPATH"
  enable_intranode_visibility = true
  network_policy {
    enabled = false
  }

  # Pool temporal por defecto; GKE lo borra al terminar de crear el cluster.
  node_config {
    disk_size_gb    = 20
    machine_type    = "e2-micro"
    service_account = var.node_service_account
    oauth_scopes    = local.oauth_scopes

    # Pool temporario (se elimina al crear el clúster), pero sus VM también pasan por compute.requireShieldedVm.
    shielded_instance_config {
      enable_secure_boot          = var.enable_shielded_nodes
      enable_integrity_monitoring = var.enable_shielded_nodes
    }
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = var.enable_private_endpoint
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.master_authorized_networks
      content {
        cidr_block   = cidr_blocks.value.cidr_block
        display_name = cidr_blocks.value.display_name
      }
    }
  }

  release_channel {
    channel = var.release_channel
  }

  dynamic "binary_authorization" {
    for_each = var.enable_binary_authorization ? [1] : []
    content {
      evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
    }
  }

  dynamic "workload_identity_config" {
    for_each = var.enable_workload_identity ? [1] : []
    content {
      workload_pool = "${var.project_id}.svc.id.goog"
    }
  }

  dynamic "database_encryption" {
    for_each = var.database_encryption_key != null ? [1] : []
    content {
      state    = "ENCRYPTED"
      key_name = var.database_encryption_key
    }
  }

  # node_config solo describe el pool temporal que remove_default_node_pool borra; sin esto, cada plan reemplaza el clúster.
  lifecycle {
    ignore_changes = [node_config]
  }
}

resource "google_container_node_pool" "pools" {
  for_each = var.node_pools

  name               = each.key
  project            = var.project_id
  location           = local.location
  cluster            = google_container_cluster.primary.name
  initial_node_count = each.value.min_count

  autoscaling {
    min_node_count = each.value.min_count
    max_node_count = each.value.max_count
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type    = each.value.machine_type
    disk_size_gb    = 20
    image_type      = "COS_CONTAINERD"
    service_account = var.node_service_account
    oauth_scopes    = local.oauth_scopes
    labels          = var.labels

    # Etiqueta segura (tagKeys/ID = tagValues/ID) que seleccionan las reglas de la política de firewall.
    resource_manager_tags = var.resource_manager_tags

    shielded_instance_config {
      enable_secure_boot          = var.enable_shielded_nodes
      enable_integrity_monitoring = var.enable_shielded_nodes
    }

    dynamic "workload_metadata_config" {
      for_each = var.enable_workload_identity ? [1] : []
      content {
        mode = "GKE_METADATA"
      }
    }

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }

  # El autoscaler mueve el número de nodos; no recrear el pool por eso. Si se recrea el clúster (mismo nombre),
  # el pool también, o Terraform conservaría en el estado un pool que ya no existe.
  lifecycle {
    ignore_changes       = [initial_node_count]
    replace_triggered_by = [google_container_cluster.primary]
  }
}

