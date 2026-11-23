output "notification_channel_id" {
  description = "ID del canal de notificación por correo."
  value       = google_monitoring_notification_channel.email.id
}

output "alert_policy_ids" {
  description = "IDs de las políticas de alerta creadas, por llave (gke_node_cpu, sql_cpu, sql_replica_lag, vpn_tunnel_down)."
  value       = { for k, p in google_monitoring_alert_policy.this : k => p.id }
}

output "dashboard_id" {
  description = "ID del tablero de monitoreo del entorno."
  value       = google_monitoring_dashboard.this.id
}
