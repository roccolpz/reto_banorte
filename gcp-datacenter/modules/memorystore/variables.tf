variable "name" {
  description = "Nombre de la instancia de Memorystore for Redis."
  type        = string
}

variable "project_id" {
  description = "Proyecto de la instancia."
  type        = string
}

variable "region" {
  description = "Región de la instancia."
  type        = string
  default     = "us-central1"
}

variable "network" {
  description = "self_link o ID de la VPC (compartida) con acceso a servicios privados ya configurado."
  type        = string
}

variable "tier" {
  description = "BASIC (una zona) o STANDARD_HA (réplica en otra zona)."
  type        = string
  default     = "BASIC"

  validation {
    condition     = contains(["BASIC", "STANDARD_HA"], var.tier)
    error_message = "tier debe ser BASIC o STANDARD_HA."
  }
}

variable "memory_size_gb" {
  description = "Memoria en GB."
  type        = number
  default     = 1
}

variable "redis_version" {
  description = "Versión de Redis."
  type        = string
  default     = "REDIS_7_2"
}

variable "labels" {
  description = "Etiquetas. Deben incluir env, app, owner, cost_center y managed_by."
  type        = map(string)

  validation {
    condition     = alltrue([for k in ["env", "app", "owner", "cost_center", "managed_by"] : contains(keys(var.labels), k)])
    error_message = "labels debe incluir env, app, owner, cost_center y managed_by."
  }
}
