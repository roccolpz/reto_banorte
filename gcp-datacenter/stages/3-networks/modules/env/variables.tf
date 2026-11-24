variable "env" {
  description = "Entorno: dev, qa o prod. Elige la fila de direccionamiento del contrato (§5)."
  type        = string

  validation {
    condition     = contains(["dev", "qa", "prod"], var.env)
    error_message = "env debe ser dev, qa o prod."
  }
}

variable "host_project_id" {
  description = "Proyecto host de la Shared VPC del entorno (salida net_host_project_ids de 1-org)."
  type        = string
}

variable "hub_network_self_link" {
  description = "Self link de la VPC hub (salida de 3-networks/hub)."
  type        = string
}

variable "ncc_hub_id" {
  description = "ID del hub de NCC (salida de 3-networks/hub)."
  type        = string
}

variable "corp_dns_domain" {
  description = "Dominio DNS corporativo que se reenvía a on-prem (salida de 3-networks/hub)."
  type        = string
}

variable "onprem_cidrs" {
  description = "Rangos on-prem (salida de 3-networks/hub). Solo entran por HTTP/HTTPS a las cargas etiquetadas."
  type        = list(string)
}

variable "prefix" {
  description = "Prefijo de la empresa en los nombres."
  type        = string
  default     = "acme"
}

variable "labels" {
  description = "Etiquetas obligatorias del contrato (env, app, owner, cost_center, managed_by)."
  type        = map(string)

  validation {
    condition     = alltrue([for k in ["env", "app", "owner", "cost_center", "managed_by"] : contains(keys(var.labels), k)])
    error_message = "labels debe incluir env, app, owner, cost_center y managed_by."
  }
}
