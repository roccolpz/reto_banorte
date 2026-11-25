variable "name" {
  description = "Prefijo de la bóveda y del plan de respaldo."
  type        = string
}

variable "project_id" {
  description = "Proyecto de la bóveda y de las instancias de Cloud SQL a respaldar."
  type        = string
}

variable "region" {
  description = "Región de la bóveda y del plan; debe ser la de las instancias de Cloud SQL."
  type        = string
  default     = "us-central1"
}

variable "sql_instances" {
  description = "Instancias de Cloud SQL a respaldar: llave estable → nombre de la instancia."
  type        = map(string)
  default     = {}
}

variable "retention_days" {
  description = "Retención de cada respaldo y retención mínima forzada de la bóveda, en días."
  type        = number
  default     = 30

  validation {
    condition     = var.retention_days >= 2 && var.retention_days <= 90
    error_message = "retention_days debe estar entre 2 y 90."
  }
}

variable "log_retention_days" {
  description = "Días que se guardan los logs de transacciones de Cloud SQL (PITR desde la bóveda). Debe ser menor que retention_days."
  type        = number
  default     = 7

  validation {
    condition     = var.log_retention_days >= 1 && var.log_retention_days < var.retention_days
    error_message = "log_retention_days debe ser al menos 1 y menor que retention_days."
  }
}

variable "backup_window_start_hour" {
  description = "Hora de inicio (0-18) de la ventana diaria de respaldo, de 6 horas (mínimo de la API)."
  type        = number
  default     = 2

  validation {
    condition     = var.backup_window_start_hour >= 0 && var.backup_window_start_hour <= 18
    error_message = "backup_window_start_hour debe estar entre 0 y 18."
  }
}

variable "time_zone" {
  description = "Zona horaria de la ventana de respaldo."
  type        = string
  default     = "America/Mexico_City"
}

variable "labels" {
  description = "Etiquetas. Deben incluir env, app, owner, cost_center y managed_by."
  type        = map(string)

  validation {
    condition     = alltrue([for k in ["env", "app", "owner", "cost_center", "managed_by"] : contains(keys(var.labels), k)])
    error_message = "labels debe incluir env, app, owner, cost_center y managed_by."
  }
}
