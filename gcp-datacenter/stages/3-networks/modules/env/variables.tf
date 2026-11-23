variable "env" {
  description = "Entorno: dev, qa o prod. Elige la fila de direccionamiento del contrato (§5)."
  type        = string

  validation {
    condition     = contains(["dev", "qa", "prod"], var.env)
    error_message = "env debe ser dev, qa o prod."
  }
}

variable "state_bucket" {
  description = "Bucket GCS del estado (lee 1-org y 3-networks/hub)."
  type        = string
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
