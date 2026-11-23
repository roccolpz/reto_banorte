variable "project_id" {
  description = "Proyecto donde viven ambas VPC, los gateways y los túneles. Para spokes híbridos de NCC debe ser el mismo proyecto del hub."
  type        = string
}

variable "region" {
  description = "Región de los gateways HA VPN y Cloud Routers."
  type        = string

  validation {
    condition     = contains(["us-central1", "us-east4"], var.region)
    error_message = "region debe ser us-central1 o us-east4."
  }
}

variable "name" {
  description = "Prefijo de nombres del lado GCP (hub), p. ej. `acme-common-net-hub`."
  type        = string
}

variable "peer_name" {
  description = "Prefijo de nombres del lado par (on-prem simulado), p. ej. `acme-onprem-sim`."
  type        = string
}

variable "network" {
  description = "Self link de la VPC del lado GCP (hub)."
  type        = string
}

variable "peer_network" {
  description = "Self link de la VPC par (on-prem simulado con un HA VPN de GCP)."
  type        = string
}

variable "asn" {
  description = "ASN del Cloud Router del lado GCP."
  type        = number
  default     = 64514
}

variable "peer_asn" {
  description = "ASN del Cloud Router del lado on-prem."
  type        = number
  default     = 65001
}

variable "advertised_ranges" {
  description = "Rangos personalizados que anuncia el lado GCP (además de sus subredes)."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for c in var.advertised_ranges : can(cidrhost(c, 0))])
    error_message = "advertised_ranges debe contener CIDR válidos."
  }
}

variable "peer_advertised_ranges" {
  description = "Rangos personalizados que anuncia el lado on-prem (además de sus subredes)."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for c in var.peer_advertised_ranges : can(cidrhost(c, 0))])
    error_message = "peer_advertised_ranges debe contener CIDR válidos."
  }
}

variable "bgp_cidrs" {
  description = "Dos rangos /30 link-local (169.254.0.0/16), uno por túnel. La IP .1 es del lado GCP y la .2 del lado on-prem. Deben ser únicos por región."
  type        = list(string)
  default     = ["169.254.0.0/30", "169.254.1.0/30"]

  validation {
    condition = length(var.bgp_cidrs) == 2 && alltrue([
      for c in var.bgp_cidrs : can(cidrhost(c, 0)) && endswith(c, "/30") && startswith(c, "169.254.")
    ])
    error_message = "bgp_cidrs debe tener exactamente dos rangos /30 dentro de 169.254.0.0/16."
  }
}

variable "ncc_hub_id" {
  description = "ID del hub de NCC donde se registra el spoke híbrido (grupo `center`)."
  type        = string
  default     = null
}

# Bool aparte de ncc_hub_id: el id del hub suele ser desconocido hasta el apply y no puede decidir un count.
variable "create_ncc_spoke" {
  description = "true registra los túneles del lado GCP como spoke híbrido de NCC. Requiere ncc_hub_id."
  type        = bool
  default     = false

  validation {
    condition     = !var.create_ncc_spoke || var.ncc_hub_id != null
    error_message = "create_ncc_spoke = true requiere ncc_hub_id."
  }
}

variable "labels" {
  description = "Etiquetas obligatorias del contrato (env, app, owner, cost_center, managed_by)."
  type        = map(string)

  validation {
    condition     = alltrue([for k in ["env", "app", "owner", "cost_center", "managed_by"] : contains(keys(var.labels), k)])
    error_message = "labels debe incluir env, app, owner, cost_center y managed_by."
  }
}
