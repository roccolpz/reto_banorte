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
  description = "Sufijo de 4 caracteres hexadecimales que hace únicos los IDs globales (proyectos, buckets, keyrings)"
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{4}$", var.suffix))
    error_message = "suffix debe ser de 4 caracteres hexadecimales en minúsculas."
  }
}

variable "region" {
  description = "Región del bucket de estado y del keyring"
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

variable "github_repository" {
  description = "Repositorio de GitHub (owner/nombre) que puede autenticarse por WIF"
  type        = string
  default     = "roccolpz/reto_banorte"

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository debe tener el formato owner/repositorio."
  }
}

variable "budget_amount" {
  description = "Presupuesto mensual de la cuenta de facturación, en unidades de budget_currency."
  type        = number
  default     = 300

  validation {
    condition     = var.budget_amount > 0
    error_message = "budget_amount debe ser mayor que cero."
  }
}

variable "budget_currency" {
  description = "Moneda del presupuesto (ISO 4217); debe ser la de la cuenta de facturación."
  type        = string
  default     = "USD"
}

variable "budget_thresholds" {
  description = "Umbrales de gasto real que disparan alerta (1.0 = 100 %)."
  type        = list(number)
  default     = [0.5, 0.9, 1.0]
}
