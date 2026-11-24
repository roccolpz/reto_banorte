variable "state_bucket" {
  description = "Bucket GCS del estado de Terraform (salida state_bucket de 0-bootstrap)."
  type        = string
}

variable "prefix" {
  description = "Prefijo de la empresa en los nombres."
  type        = string
  default     = "acme"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,9}$", var.prefix))
    error_message = "prefix: minúsculas y números, 2 a 10 caracteres, empieza con letra."
  }
}

variable "labels" {
  description = "Etiquetas base; env y managed_by las agrega la etapa."
  type        = map(string)
  default = {
    app         = "landing-zone"
    owner       = "platform"
    cost_center = "infra"
  }

  validation {
    condition     = alltrue([for k in ["app", "owner", "cost_center"] : contains(keys(var.labels), k)])
    error_message = "labels debe incluir app, owner y cost_center."
  }
}

variable "vpn_regions" {
  description = "Regiones con HA VPN hacia onprem-sim. Cada región agrega 2 gateways, 4 túneles y un spoke híbrido."
  type        = list(string)
  default     = ["us-central1", "us-east4"]

  validation {
    condition     = length(var.vpn_regions) > 0 && length(distinct(var.vpn_regions)) == length(var.vpn_regions) && alltrue([for r in var.vpn_regions : contains(["us-central1", "us-east4"], r)])
    error_message = "vpn_regions: al menos una, sin repetir, entre us-central1 y us-east4."
  }
}

variable "onprem_dns_target_ips" {
  description = "IPs a las que el hub reenvía corp.acme.internal. Vacío = IP del forwarder entrante de onprem-sim, descubierta en el apply."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for ip in var.onprem_dns_target_ips : can(cidrhost("${ip}/32", 0))])
    error_message = "onprem_dns_target_ips: cada valor debe ser una IPv4."
  }
}
