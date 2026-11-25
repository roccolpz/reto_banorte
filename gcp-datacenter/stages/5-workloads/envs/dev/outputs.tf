output "gke_cluster_name" {
  description = "Nombre del clúster GKE."
  value       = module.env.gke_cluster_name
}

output "gke_dr_cluster_name" {
  description = "Nombre del clúster GKE DR en us-east4; null en dev y qa."
  value       = module.env.gke_dr_cluster_name
}

output "sql_instance_name" {
  description = "Nombre de la instancia primaria de Cloud SQL."
  value       = module.env.sql_instance_name
}

output "sql_private_ip" {
  description = "IP privada de la instancia primaria de Cloud SQL."
  value       = module.env.sql_private_ip
}

output "bucket_name" {
  description = "Nombre del bucket de la aplicación."
  value       = module.env.bucket_name
}

output "mig_name" {
  description = "Nombre del grupo de instancias administrado."
  value       = module.env.mig_name
}

output "cloud_run_service" {
  description = "Nombre del servicio de Cloud Run."
  value       = module.env.cloud_run_service
}

output "lb_ip_address" {
  description = "IP pública del balanceador; null si no se crea (dev y qa)."
  value       = module.env.lb_ip_address
}

output "lb_domain" {
  description = "Dominio HTTPS del balanceador; null si no se crea."
  value       = module.env.lb_domain
}

output "redis_host" {
  description = "IP privada de Memorystore; null si no se crea."
  value       = module.env.redis_host
}

output "backup_vault_id" {
  description = "Bóveda de Backup and DR; null si no se crea."
  value       = module.env.backup_vault_id
}
