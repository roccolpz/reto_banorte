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
