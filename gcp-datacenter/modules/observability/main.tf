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
    vpn_tunnel_down = {
      enabled    = var.enable_vpn_alert
      title      = "Túnel VPN caído"
      filter     = "metric.type=\"vpn.googleapis.com/tunnel_established\" AND resource.type=\"vpn_gateway\""
      comparison = "COMPARISON_LT"
      threshold  = 1
    }
  }
}

resource "google_monitoring_notification_channel" "email" {
  project      = var.project_id
  display_name = "${var.name_prefix} correo de alertas"
  type         = "email"
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
  for_each = { for k, a in local.alerts : k => a if a.enabled }

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

resource "google_monitoring_uptime_check_config" "this" {
  count = var.uptime_check_host == null ? 0 : 1

  project      = var.project_id
  display_name = "${var.name_prefix} uptime ${var.uptime_check_host}"
  timeout      = "10s"
  period       = "60s"

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
