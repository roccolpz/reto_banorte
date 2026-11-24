variable "name" {
  description = "Nombre descriptivo del proyecto"
  type        = string
}

variable "project_id" {
  description = "ID único del proyecto en GCP (6 a 30 caracteres: minúsculas, dígitos y guiones; empieza con letra)"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id debe tener 6 a 30 caracteres, minúsculas, dígitos o guiones, empezar con letra y no terminar en guion."
  }
}

variable "folder_id" {
  description = "Carpeta contenedora, como folders/<id> o solo el número (ej. carpeta dev, qa o prod)"
  type        = string
}

variable "billing_account" {
  description = "ID de la cuenta de facturación de GCP"
  type        = string
}

variable "shared_vpc_host_project_id" {
  description = "ID del proyecto host de la Shared VPC; vacío para no adjuntar el proyecto como proyecto de servicio"
  type        = string
  default     = ""
}

variable "activate_apis" {
  description = "Lista de APIs de Google a habilitar en el proyecto"
  type        = list(string)
  default     = ["compute.googleapis.com", "container.googleapis.com"]
}

variable "labels" {
  description = "Etiquetas del proyecto. Deben incluir env, app, owner, cost_center y managed_by."
  type        = map(string)

  validation {
    condition = alltrue([
      for k in ["env", "app", "owner", "cost_center", "managed_by"] : contains(keys(var.labels), k)
    ])
    error_message = "labels debe incluir las llaves env, app, owner, cost_center y managed_by."
  }
}

variable "auto_create_network" {
  description = "Si es true, GCP crea la red default al crear el proyecto. Default false: las redes las crea la etapa 3-networks."
  type        = bool
  default     = false
}

variable "deletion_policy" {
  description = "Qué hace terraform destroy con el proyecto: DELETE, PREVENT o ABANDON"
  type        = string
  default     = "DELETE"

  validation {
    condition     = contains(["DELETE", "PREVENT", "ABANDON"], var.deletion_policy)
    error_message = "deletion_policy debe ser DELETE, PREVENT o ABANDON."
  }
}
