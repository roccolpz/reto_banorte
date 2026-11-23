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
