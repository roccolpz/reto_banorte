variable "org_id" {
  description = "ID numérico de la organización de GCP"
  type        = string

  validation {
    condition     = can(regex("^[0-9]+$", var.org_id))
    error_message = "org_id debe ser numérico (sin el prefijo organizations/)."
  }
}

variable "billing_account" {
  description = "Cuenta de facturación (formato XXXXXX-XXXXXX-XXXXXX)"
  type        = string

  validation {
    condition     = can(regex("^[0-9A-F]{6}-[0-9A-F]{6}-[0-9A-F]{6}$", var.billing_account))
    error_message = "billing_account debe tener el formato XXXXXX-XXXXXX-XXXXXX en hexadecimal mayúsculas."
  }
}

variable "state_bucket" {
  description = "Bucket de estado creado por 0-bootstrap (salida state_bucket)"
  type        = string
}

variable "prefix" {
  description = "Prefijo de la empresa en nombres de recursos"
  type        = string
  default     = "acme"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,9}$", var.prefix))
    error_message = "prefix debe tener 2 a 10 caracteres en minúsculas y empezar con letra."
  }
}

variable "suffix" {
  description = "Sufijo de 4 caracteres hexadecimales que hace únicos los IDs globales"
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{4}$", var.suffix))
    error_message = "suffix debe ser de 4 caracteres hexadecimales en minúsculas."
  }
}

variable "region" {
  description = "Región primaria (bucket de auditoría)"
  type        = string
  default     = "us-central1"

  validation {
    condition     = contains(["us-central1", "us-east4"], var.region)
    error_message = "region debe ser us-central1 o us-east4."
  }
}

variable "labels" {
  description = "Etiquetas base. Deben incluir app, owner y cost_center; la raíz agrega env y managed_by."
  type        = map(string)

  validation {
    condition     = alltrue([for k in ["app", "owner", "cost_center"] : contains(keys(var.labels), k)])
    error_message = "labels debe incluir las llaves app, owner y cost_center."
  }
}

variable "groups" {
  description = "Correos de los grupos humanos (Fase 3, §3.2). Llaves válidas: org_admins, break_glass, billing_admins, security_admins, network_admins, devops, developers, auditors. break_glass es el acceso de emergencia (ADR 0009-g). Vacío: no se crean bindings."
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for k in keys(var.groups) : contains(["org_admins", "break_glass", "billing_admins", "security_admins", "network_admins", "devops", "developers", "auditors"], k)
    ])
    error_message = "groups solo acepta las llaves org_admins, break_glass, billing_admins, security_admins, network_admins, devops, developers y auditors."
  }
}

variable "allowed_policy_member_customer_ids" {
  description = "IDs de cliente de Cloud Identity (C0xxxxxxx) permitidos en IAM (iam.allowedPolicyMemberDomains). Vacío: no se aplica la política."
  type        = list(string)
  default     = []
}

variable "audit_retention_days" {
  description = "Días de retención del bucket de auditoría"
  type        = number
  default     = 365

  validation {
    condition     = var.audit_retention_days >= 1 && var.audit_retention_days <= 3650
    error_message = "audit_retention_days debe estar entre 1 y 3650."
  }
}

variable "audit_retention_locked" {
  description = "Bloquea la retención del bucket de auditoría. IRREVERSIBLE: el bucket no se puede borrar hasta que venza la retención."
  type        = bool
  default     = false
}

variable "compact_projects" {
  description = "Modo de prueba con poca cuota de facturación: un proyecto common y un proyecto por entorno (red, app y datos juntos). false es el diseño completo."
  type        = bool
  default     = false
}
