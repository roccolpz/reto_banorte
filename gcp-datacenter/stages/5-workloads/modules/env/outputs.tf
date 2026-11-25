output "gke_cluster_name" {
  description = "Nombre del clúster GKE."
  value       = module.gke.cluster_name
}

output "gke_dr_cluster_name" {
  description = "Nombre del clúster GKE DR en dr_region; null si no se crea (dev y qa)."
  value       = one(module.gke_dr[*].cluster_name)
}

output "sql_instance_name" {
  description = "Nombre de la instancia primaria de Cloud SQL."
  value       = module.sql.instance_name
}

output "sql_private_ip" {
  description = "IP privada de la instancia primaria de Cloud SQL."
  value       = module.sql.private_ip_address
}

output "bucket_name" {
  description = "Nombre del bucket de la aplicación."
  value       = module.storage.bucket_name
}

output "mig_name" {
  description = "Nombre del grupo de instancias administrado."
  value       = module.mig.mig_name
}

output "cloud_run_service" {
  description = "Nombre del servicio de Cloud Run; null si 4-projects aún no crea la SA run."
  value       = one(module.cloud_run[*].service_name)
}

output "lb_ip_address" {
  description = "IP pública del balanceador; null si no se crea (dev y qa)."
  value       = one(module.load_balancer[*].ip_address)
}

output "lb_domain" {
  description = "Dominio HTTPS del balanceador; null si no se crea."
  value       = one(module.load_balancer[*].domain)
}

output "redis_host" {
  description = "IP privada de Memorystore; null si no se crea."
  value       = one(module.memorystore[*].host)
}

output "backup_vault_id" {
  description = "Bóveda de Backup and DR; null si no se crea."
  value       = one(module.backup_dr[*].vault_id)
}
