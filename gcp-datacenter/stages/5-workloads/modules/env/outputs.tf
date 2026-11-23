output "gke_cluster_name" {
  description = "Nombre del clúster GKE."
  value       = module.gke.cluster_name
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
