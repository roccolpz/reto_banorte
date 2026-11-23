output "tunnel_self_links" {
  description = "Self links de los dos túneles del lado GCP (hub)."
  value       = google_compute_vpn_tunnel.local[*].self_link
}

output "peer_tunnel_self_links" {
  description = "Self links de los dos túneles del lado on-prem."
  value       = google_compute_vpn_tunnel.peer[*].self_link
}

output "router_name" {
  description = "Nombre del Cloud Router del lado GCP."
  value       = google_compute_router.local.name
}

output "peer_router_name" {
  description = "Nombre del Cloud Router del lado on-prem."
  value       = google_compute_router.peer.name
}

output "ncc_spoke_id" {
  description = "ID del spoke híbrido de NCC, o null si no se registró."
  value       = one(google_network_connectivity_spoke.vpn[*].id)
}
