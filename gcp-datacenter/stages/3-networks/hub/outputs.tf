output "hub_project_id" {
  description = "Proyecto del hub de red."
  value       = local.hub_project_id
}

output "hub_network_id" {
  description = "ID de la VPC del hub."
  value       = module.hub.network_id
}

output "hub_network_self_link" {
  description = "Self link de la VPC del hub (destino del DNS peering de los entornos)."
  value       = module.hub.network_self_link
}

output "ncc_hub_id" {
  description = "ID del hub de NCC; los entornos se unen al grupo edge."
  value       = module.hub.ncc_hub_id
}

output "onprem_cidrs" {
  description = "Rangos on-prem."
  value       = local.onprem_cidrs
}

output "corp_dns_domain" {
  description = "Dominio corporativo resuelto vía on-prem."
  value       = local.corp_dns_domain
}
