output "network_id" {
  description = "ID de la VPC del hub."
  value       = google_compute_network.hub.id
}

output "network_self_link" {
  description = "Self link de la VPC del hub (destino del DNS peering de los entornos)."
  value       = google_compute_network.hub.self_link
}

output "network_name" {
  description = "Nombre de la VPC del hub."
  value       = google_compute_network.hub.name
}

output "subnets" {
  description = "Subredes del hub: región -> { id, self_link, name, cidr }."
  value = { for r, s in google_compute_subnetwork.hub : r => {
    id        = s.id
    self_link = s.self_link
    name      = s.name
    cidr      = s.ip_cidr_range
  } }
}

output "ncc_hub_id" {
  description = "ID del hub de NCC (`projects/<p>/locations/global/hubs/<nombre>`)."
  value       = google_network_connectivity_hub.hub.id
}

output "corp_forwarding_zone_name" {
  description = "Nombre de la zona de reenvío del dominio corporativo."
  value       = google_dns_managed_zone.corp_forwarding.name
}
