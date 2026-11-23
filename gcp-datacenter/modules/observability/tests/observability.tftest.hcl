mock_provider "google" {}

variables {
  project_id            = "acme-dev-app-ab12"
  name_prefix           = "acme-dev"
  notification_email    = "noc@example.com"
  monitored_project_ids = ["acme-dev-data-ab12"]
  labels = {
    env = "dev", app = "landing-zone", owner = "plataforma", cost_center = "TI-001", managed_by = "terraform"
  }
}

run "canal_alertas_y_tablero_por_defecto" {
  command = plan

  assert {
    condition     = google_monitoring_notification_channel.email.labels["email_address"] == "noc@example.com"
    error_message = "El canal de notificación usa el correo de la variable."
  }

  assert {
    condition     = google_monitoring_notification_channel.email.user_labels == var.labels
    error_message = "El canal lleva las etiquetas obligatorias en user_labels (policies/labels.rego)."
  }

  assert {
    condition     = toset(keys(google_monitoring_alert_policy.this)) == toset(["gke_node_cpu", "sql_cpu", "sql_replica_lag", "vpn_tunnel_down"])
    error_message = "Por defecto se crean las alertas de CPU de nodos GKE, CPU de Cloud SQL, retraso de réplica y túnel VPN caído."
  }

  assert {
    condition     = strcontains(google_monitoring_alert_policy.this["sql_replica_lag"].conditions[0].condition_threshold[0].filter, "cloudsql.googleapis.com/database/replication/replica_lag")
    error_message = "La alerta de réplica usa la métrica replica_lag."
  }

  assert {
    condition     = google_monitoring_alert_policy.this["sql_replica_lag"].conditions[0].condition_threshold[0].threshold_value == 60
    error_message = "La alerta de réplica salta con más de 60 s de retraso por defecto."
  }

  assert {
    condition     = jsondecode(google_monitoring_dashboard.this.dashboard_json).displayName == "acme-dev landing zone"
    error_message = "Se crea un tablero con el prefijo del entorno."
  }

  assert {
    condition     = length(jsondecode(google_monitoring_dashboard.this.dashboard_json).gridLayout.widgets) == 4
    error_message = "El tablero tiene una gráfica por alerta activa."
  }

  assert {
    condition     = strcontains(google_monitoring_alert_policy.this["vpn_tunnel_down"].conditions[0].condition_threshold[0].filter, "vpn.googleapis.com/tunnel_established")
    error_message = "La alerta de VPN usa la métrica tunnel_established."
  }

  assert {
    condition     = google_monitoring_monitored_project.this["acme-dev-data-ab12"].metrics_scope == "locations/global/metricsScopes/acme-dev-app-ab12"
    error_message = "Los proyectos monitoreados se agregan al metrics scope del proyecto."
  }

  assert {
    condition     = length(google_logging_metric.this) == 0 && length(google_monitoring_uptime_check_config.this) == 0
    error_message = "Métrica de logs y uptime check son opcionales."
  }
}

run "uptime_y_metrica_de_logs_opcionales" {
  command = plan

  variables {
    enable_vpn_alert         = false
    enable_replica_lag_alert = false
    uptime_check_host        = "app.example.com"
    log_metric = {
      name   = "acme-dev-iam-changes"
      filter = "protoPayload.methodName=\"SetIamPolicy\""
    }
  }

  assert {
    condition     = !contains(keys(google_monitoring_alert_policy.this), "vpn_tunnel_down")
    error_message = "enable_vpn_alert = false quita la alerta de VPN."
  }

  assert {
    condition     = !contains(keys(google_monitoring_alert_policy.this), "sql_replica_lag")
    error_message = "enable_replica_lag_alert = false quita la alerta de réplica."
  }

  assert {
    condition     = length(jsondecode(google_monitoring_dashboard.this.dashboard_json).gridLayout.widgets) == 2
    error_message = "El tablero solo grafica las alertas activas."
  }

  assert {
    condition     = google_monitoring_uptime_check_config.this[0].monitored_resource[0].labels["host"] == "app.example.com"
    error_message = "El uptime check apunta al host dado."
  }

  assert {
    condition     = google_monitoring_uptime_check_config.this[0].user_labels == var.labels
    error_message = "El uptime check lleva las etiquetas obligatorias en user_labels (policies/labels.rego)."
  }

  assert {
    condition     = google_logging_metric.this[0].name == "acme-dev-iam-changes"
    error_message = "Se crea la métrica basada en logs."
  }
}

run "rechaza_correo_invalido" {
  command = plan

  variables {
    notification_email = "no-es-correo"
  }

  expect_failures = [var.notification_email]
}
