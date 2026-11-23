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
    error_message = "prefix: minúsculas y números, 2 a 10 caracteres, empieza con letra (también se usa en nombres de perímetro)."
  }
}

variable "suffix" {
  description = "4 caracteres hex que hacen únicos los nombres globales (keyrings)."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{4}$", var.suffix))
    error_message = "suffix debe ser 4 caracteres hexadecimales en minúscula."
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

variable "org_id" {
  description = "ID numérico de la organización. Solo se usa si create_access_policy = true."
  type        = string
  default     = null

  validation {
    condition     = !var.create_access_policy || can(regex("^[0-9]+$", var.org_id))
    error_message = "org_id numérico es obligatorio cuando create_access_policy = true."
  }
}

variable "create_access_policy" {
  description = "true crea la política de Access Context Manager de la organización (solo puede existir una). false usa access_policy_name existente."
  type        = bool
  default     = false
}

variable "access_policy_name" {
  description = "Número de la política de Access Context Manager existente. Obligatorio si create_access_policy = false."
  type        = string
  default     = null

  validation {
    condition     = var.create_access_policy || can(regex("^[0-9]+$", var.access_policy_name))
    error_message = "access_policy_name (número) es obligatorio cuando create_access_policy = false."
  }
}

variable "vpc_sc_enforce" {
  description = "false: perímetros en dry-run (solo registran violaciones). true: perímetros aplicados. Revisar los logs de dry-run antes de cambiarlo."
  type        = bool
  default     = false
}

variable "restricted_services" {
  description = "Servicios de datos protegidos por cada perímetro. KMS y Secret Manager no se incluyen: sus recursos viven en el proyecto común de seguridad, fuera de los perímetros de entorno."
  type        = list(string)
  default = [
    "storage.googleapis.com",
    "sqladmin.googleapis.com",
    "bigquery.googleapis.com",
  ]
}

variable "secret_names" {
  description = "Secretos (solo contenedor, sin versión ni valor) que se crean por entorno."
  type        = list(string)
  default     = ["db-app-password"]

  validation {
    condition     = alltrue([for s in var.secret_names : can(regex("^[a-z][a-z0-9-]{0,40}$", s))])
    error_message = "Cada nombre de secreto: minúsculas, números y guiones, empieza con letra."
  }
}
