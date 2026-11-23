output "network_id" {
  description = "ID de la VPC del entorno."
  value       = google_compute_network.this.id
}

output "network_self_link" {
  description = "Self link de la VPC del entorno."
  value       = google_compute_network.this.self_link
}

output "network_name" {
  description = "Nombre de la VPC del entorno."
  value       = google_compute_network.this.name
}

output "subnets" {
  description = "Subredes app: región -> { id, self_link, name, cidr, pods_range_name, services_range_name }."
  value = { for r, s in google_compute_subnetwork.app : r => {
    id                  = s.id
    self_link           = s.self_link
    name                = s.name
    cidr                = s.ip_cidr_range
    pods_range_name     = "pods"
    services_range_name = "services"
  } }
}

output "psa_connection_id" {
  description = "ID de la conexión de Private Service Access, o null si no hay PSA."
  value       = one(google_service_networking_connection.psa[*].id)
}

output "dns_zone_name" {
  description = "Nombre de la zona DNS privada del entorno."
  value       = google_dns_managed_zone.private.name
}

output "dns_domain" {
  description = "Dominio de la zona privada (`<env>.gcp.<prefix>.internal.`)."
  value       = google_dns_managed_zone.private.dns_name
}

output "ncc_spoke_id" {
  description = "ID del VPC spoke de NCC, o null si no se registró."
  value       = one(google_network_connectivity_spoke.vpc[*].id)
}
