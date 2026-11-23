variable "name" {
  description = "Nombre de la instancia primaria. La réplica DR usa <name>-dr."
  type        = string
}

variable "project_id" {
  description = "Proyecto de servicio (datos) donde se crea la instancia."
  type        = string
}

variable "region" {
  description = "Región de la instancia primaria."
  type        = string
  default     = "us-central1"

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]$", var.region))
    error_message = "region debe ser una región de GCP, p. ej. us-central1."
  }
}

variable "network" {
  description = "ID o self link de la VPC del host con Private Service Access ya configurado (3-networks)."
  type        = string
}

variable "database_version" {
  description = "Versión de PostgreSQL."
  type        = string
  default     = "POSTGRES_16"

  validation {
    condition     = startswith(var.database_version, "POSTGRES_")
    error_message = "database_version debe ser una versión de PostgreSQL (POSTGRES_*)."
  }
}

variable "tier" {
  description = "Tipo de máquina de Cloud SQL."
  type        = string
  default     = "db-custom-1-3840"
}

variable "disk_size_gb" {
  description = "Tamaño inicial del disco SSD (crece solo)."
  type        = number
  default     = 10
}

variable "kms_key_name" {
  description = "ID de la llave KMS (misma región que la primaria) para CMEK."
  type        = string
}

variable "ha" {
  description = "true crea la primaria con alta disponibilidad regional (REGIONAL)."
  type        = bool
  default     = false
}

variable "enable_dr_replica" {
  description = "true crea una réplica de lectura entre regiones en dr_region."
  type        = bool
  default     = false
}

variable "dr_region" {
  description = "Región de la réplica DR."
  type        = string
  default     = "us-east4"

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]$", var.dr_region))
    error_message = "dr_region debe ser una región de GCP, p. ej. us-east4."
  }
}

variable "dr_kms_key_name" {
  description = "ID de la llave KMS en dr_region para la réplica. Obligatoria si enable_dr_replica = true."
  type        = string
  default     = null

  validation {
    condition     = !var.enable_dr_replica || var.dr_kms_key_name != null
    error_message = "dr_kms_key_name es obligatoria cuando enable_dr_replica = true."
  }
}

variable "backup_start_time" {
  description = "Hora UTC (HH:MM) de inicio del respaldo diario."
  type        = string
  default     = "03:00"
}

variable "retained_backups" {
  description = "Número de respaldos diarios que se conservan."
  type        = number
  default     = 7
}

variable "transaction_log_retention_days" {
  description = "Días de logs de transacciones para PITR (1 a 7)."
  type        = number
  default     = 7

  validation {
    condition     = var.transaction_log_retention_days >= 1 && var.transaction_log_retention_days <= 7
    error_message = "transaction_log_retention_days debe estar entre 1 y 7."
  }
}

variable "deletion_protection" {
  description = "Protege las instancias contra terraform destroy."
  type        = bool
  default     = false
}

variable "labels" {
  description = "Etiquetas (user_labels). Deben incluir env, app, owner, cost_center y managed_by."
  type        = map(string)

  validation {
    condition     = alltrue([for k in ["env", "app", "owner", "cost_center", "managed_by"] : contains(keys(var.labels), k)])
    error_message = "labels debe incluir env, app, owner, cost_center y managed_by."
  }
}
