output "instance_name" {
  description = "Nombre de la instancia."
  value       = google_redis_instance.this.name
}

output "host" {
  description = "IP privada de la instancia."
  value       = google_redis_instance.this.host
}

output "port" {
  description = "Puerto de Redis."
  value       = google_redis_instance.this.port
}
