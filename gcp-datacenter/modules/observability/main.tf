locals {
  alerts = {
    gke_node_cpu = {
      enabled    = var.enable_gke_alert
      title      = "CPU de nodos GKE alta"
      filter     = "metric.type=\"kubernetes.io/node/cpu/allocatable_utilization\" AND resource.type=\"k8s_node\""
      comparison = "COMPARISON_GT"
      threshold  = var.cpu_threshold
    }
    sql_cpu = {
      enabled    = var.enable_sql_alert
      title      = "CPU de Cloud SQL alta"
      filter     = "metric.type=\"cloudsql.googleapis.com/database/cpu/utilization\" AND resource.type=\"cloudsql_database\""
      comparison = "COMPARISON_GT"
      threshold  = var.cpu_threshold
    }
    sql_replica_lag = {
      enabled    = var.enable_replica_lag_alert
      title      = "Retraso de réplica de Cloud SQL alto"
      filter     = "metric.type=\"cloudsql.googleapis.com/database/replication/replica_lag\" AND resource.type=\"cloudsql_database\""
      comparison = "COMPARISON_GT"
      threshold  = var.replica_lag_threshold_seconds
    }
    vpn_tunnel_down = {
      enabled    = var.enable_vpn_alert
      title      = "Túnel VPN caído"
      filter     = "metric.type=\"vpn.googleapis.com/tunnel_established\" AND resource.type=\"vpn_gateway\""
      comparison = "COMPARISON_LT"
      threshold  = 1
    }
  }

  enabled_alerts = { for k, a in local.alerts : k => a if a.enabled }
}

resource "google_monitoring_notification_channel" "email" {
  project      = var.project_id
  display_name = "${var.name_prefix} correo de alertas"
  type         = "email"
  user_labels  = var.labels
  labels = {
    email_address = var.notification_email
  }
}

resource "google_monitoring_monitored_project" "this" {
  for_each = toset(var.monitored_project_ids)

  metrics_scope = "locations/global/metricsScopes/${var.project_id}"
  name          = each.value
}

resource "google_monitoring_alert_policy" "this" {
  for_each = local.enabled_alerts

  project               = var.project_id
  display_name          = "${var.name_prefix} ${each.value.title}"
  combiner              = "OR"
  notification_channels = [google_monitoring_notification_channel.email.id]
  user_labels           = var.labels

  conditions {
    display_name = each.value.title

    condition_threshold {
      filter          = each.value.filter
      comparison      = each.value.comparison
      threshold_value = each.value.threshold
      duration        = "300s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  depends_on = [google_monitoring_monitored_project.this]
}

# Una gráfica por alerta activa, con la misma métrica y alineación que la alerta.
resource "google_monitoring_dashboard" "this" {
  project = var.project_id
  dashboard_json = jsonencode({
    displayName = "${var.name_prefix} landing zone"
    # Escrito como lo devuelve la API (columns en texto, targetAxis explícito) para que el plan no muestre cambios.
    gridLayout = {
      columns = "2"
      widgets = [for k, a in local.enabled_alerts : {
        title = a.title
        xyChart = {
          dataSets = [{
            plotType   = "LINE"
            targetAxis = "Y1"
            timeSeriesQuery = {
              timeSeriesFilter = {
                filter = a.filter
                aggregation = {
                  alignmentPeriod  = "60s"
                  perSeriesAligner = "ALIGN_MEAN"
                }
              }
            }
          }]
        }
      }]
    }
  })

  depends_on = [google_monitoring_monitored_project.this]
}

resource "google_monitoring_uptime_check_config" "this" {
  count = var.uptime_check_host == null ? 0 : 1

  project      = var.project_id
  display_name = "${var.name_prefix} uptime ${var.uptime_check_host}"
  timeout      = "10s"
  period       = "60s"
  user_labels  = var.labels

  http_check {
    path         = "/"
    port         = 443
    use_ssl      = true
    validate_ssl = true
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = var.uptime_check_host
    }
  }
}

resource "google_logging_metric" "this" {
  count = var.log_metric == null ? 0 : 1

  project = var.project_id
  name    = var.log_metric.name
  filter  = var.log_metric.filter

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
  }
}
