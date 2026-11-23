output "instance_name" {
  description = "Nombre de la instancia primaria."
  value       = google_sql_database_instance.primary.name
}

output "connection_name" {
  description = "Nombre de conexión (<proyecto>:<región>:<instancia>) para el Cloud SQL Auth Proxy."
  value       = google_sql_database_instance.primary.connection_name
}

output "private_ip_address" {
  description = "IP privada de la instancia primaria."
  value       = google_sql_database_instance.primary.private_ip_address
}

output "replica_name" {
  description = "Nombre de la réplica DR, o null si no existe."
  value       = one(google_sql_database_instance.replica[*].name)
}
