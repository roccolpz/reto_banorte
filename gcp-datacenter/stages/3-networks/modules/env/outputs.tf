output "host_project_id" {
  description = "Proyecto host de la Shared VPC del entorno."
  value       = local.host_project_id
}

output "network_id" {
  description = "ID de la VPC del entorno."
  value       = module.spoke.network_id
}

output "network_self_link" {
  description = "Self link de la VPC del entorno."
  value       = module.spoke.network_self_link
}

output "network_name" {
  description = "Nombre de la VPC del entorno."
  value       = module.spoke.network_name
}

output "subnets" {
  description = "Región -> { id, self_link, name, cidr, pods_range_name, services_range_name }."
  value       = module.spoke.subnets
}

output "psa_connection_id" {
  description = "ID de la conexión de Private Service Access."
  value       = module.spoke.psa_connection_id
}

output "dns_zone_name" {
  description = "Zona DNS privada del entorno."
  value       = module.spoke.dns_zone_name
}

output "dns_domain" {
  description = "Dominio de la zona privada (<env>.gcp.acme.internal.)."
  value       = module.spoke.dns_domain
}
