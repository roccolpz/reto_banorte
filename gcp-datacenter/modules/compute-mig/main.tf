resource "google_compute_instance_template" "this" {
  name_prefix  = "${var.name}-"
  project      = var.project_id
  region       = var.region
  machine_type = var.machine_type
  tags         = var.network_tags
  labels       = var.labels

  # Etiqueta segura (tagKeys/ID = tagValues/ID) que seleccionan las reglas de la política de firewall.
  resource_manager_tags = var.resource_manager_tags

  disk {
    source_image = var.image_family
    auto_delete  = true
    boot         = true
    disk_size_gb = 10
  }

  # Sin access_config: la VM no tiene IP externa; sale por Cloud NAT.
  network_interface {
    subnetwork = var.subnetwork
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  metadata = merge(
    {
      enable-oslogin         = "TRUE"
      block-project-ssh-keys = "TRUE"
      serial-port-enable     = "FALSE"
    },
    var.startup_script == null ? {} : { startup-script = var.startup_script },
  )

  service_account {
    email  = var.service_account_email
    scopes = ["cloud-platform"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_health_check" "this" {
  name    = "${var.name}-hc"
  project = var.project_id

  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3

  tcp_health_check {
    port = var.health_check_port
  }
}

resource "google_compute_region_instance_group_manager" "this" {
  name               = "${var.name}-mig"
  project            = var.project_id
  region             = var.region
  base_instance_name = var.name

  version {
    instance_template = google_compute_instance_template.this.id
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.this.id
    initial_delay_sec = 300
  }

  update_policy {
    type                  = "PROACTIVE"
    minimal_action        = "REPLACE"
    max_surge_fixed       = 3
    max_unavailable_fixed = 0
  }
}

# El autoscaler fija el número de VM; el MIG no lleva target_size para no pelear con él.
resource "google_compute_region_autoscaler" "this" {
  name    = "${var.name}-as"
  project = var.project_id
  region  = var.region
  target  = google_compute_region_instance_group_manager.this.id

  autoscaling_policy {
    min_replicas    = var.min_replicas
    max_replicas    = var.max_replicas
    cooldown_period = 90

    cpu_utilization {
      target = var.cpu_target
    }
  }
}
