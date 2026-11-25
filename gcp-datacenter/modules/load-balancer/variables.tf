variable "name" {
  description = "Prefijo de los recursos del balanceador."
  type        = string
}

variable "project_id" {
  description = "Proyecto del balanceador (el mismo del servicio de Cloud Run)."
  type        = string
}

variable "region" {
  description = "Región del servicio de Cloud Run (la del NEG serverless)."
  type        = string
  default     = "us-central1"
}

variable "cloud_run_service" {
  description = "Nombre del servicio de Cloud Run detrás del balanceador."
  type        = string
}

variable "domain" {
  description = "Dominio del certificado administrado. null: <ip>.nip.io."
  type        = string
  default     = null
}

variable "waf_sensitivity" {
  description = "Nivel de sensibilidad de las reglas WAF preconfiguradas (1 = menos falsos positivos, 4 = más estricto)."
  type        = number
  default     = 1

  validation {
    condition     = var.waf_sensitivity >= 1 && var.waf_sensitivity <= 4
    error_message = "waf_sensitivity debe estar entre 1 y 4."
  }
}

variable "labels" {
  description = "Etiquetas. Deben incluir env, app, owner, cost_center y managed_by."
  type        = map(string)

  validation {
    condition     = alltrue([for k in ["env", "app", "owner", "cost_center", "managed_by"] : contains(keys(var.labels), k)])
    error_message = "labels debe incluir env, app, owner, cost_center y managed_by."
  }
}
