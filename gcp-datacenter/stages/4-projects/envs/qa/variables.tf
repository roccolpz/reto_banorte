variable "state_bucket" {
  description = "Bucket GCS del estado de Terraform (salida state_bucket de 0-bootstrap)."
  type        = string
}

variable "prefix" {
  description = "Prefijo de la empresa en los nombres."
  type        = string
  default     = "acme"
}

variable "suffix" {
  description = "4 caracteres hex que hacen únicos los IDs de proyecto."
  type        = string
}

variable "billing_account" {
  description = "Cuenta de facturación de los proyectos de app y datos."
  type        = string
}

variable "labels" {
  description = "Etiquetas base; env y managed_by las agrega la raíz."
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

variable "vpc_sc_enforce" {
  description = "false agrega los proyectos al perímetro en dry-run; true al perímetro aplicado. Debe coincidir con 2-security."
  type        = bool
  default     = false
}
