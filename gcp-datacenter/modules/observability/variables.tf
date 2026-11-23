variable "project_id" {
  description = "Proyecto que aloja las alertas (scoping project del metrics scope)."
  type        = string
}

variable "name_prefix" {
  description = "Prefijo de nombres visibles, p. ej. acme-dev."
  type        = string
}

variable "notification_email" {
  description = "Correo que recibe las alertas."
  type        = string

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.notification_email))
    error_message = "notification_email debe ser un correo válido."
  }
}

variable "monitored_project_ids" {
  description = "Proyectos que se agregan al metrics scope de project_id (p. ej. datos y hub) para que las alertas vean sus métricas."
  type        = list(string)
  default     = []
}

variable "enable_gke_alert" {
  description = "Crea la alerta de CPU de nodos GKE."
  type        = bool
  default     = true
}

variable "enable_sql_alert" {
  description = "Crea la alerta de CPU de Cloud SQL."
  type        = bool
  default     = true
}

variable "enable_replica_lag_alert" {
  description = "Crea la alerta de retraso de la réplica de Cloud SQL (solo tiene datos donde hay réplica)."
  type        = bool
  default     = true
}

variable "replica_lag_threshold_seconds" {
  description = "Segundos de retraso de la réplica de Cloud SQL que disparan la alerta."
  type        = number
  default     = 60

  validation {
    condition     = var.replica_lag_threshold_seconds > 0
    error_message = "replica_lag_threshold_seconds debe ser mayor que 0."
  }
}

variable "enable_vpn_alert" {
  description = "Crea la alerta de túnel VPN caído."
  type        = bool
  default     = true
}

variable "cpu_threshold" {
  description = "Umbral de utilización de CPU (0 a 1) para las alertas de GKE y Cloud SQL."
  type        = number
  default     = 0.8

  validation {
    condition     = var.cpu_threshold > 0 && var.cpu_threshold <= 1
    error_message = "cpu_threshold debe estar entre 0 y 1."
  }
}

variable "uptime_check_host" {
  description = "Host HTTPS para un uptime check opcional. null no lo crea."
  type        = string
  default     = null
}

variable "log_metric" {
  description = "Métrica basada en logs opcional ({ name, filter }). null no la crea."
  type = object({
    name   = string
    filter = string
  })
  default = null
}

variable "labels" {
  description = "Etiquetas (user_labels) de las políticas de alerta. Deben incluir env, app, owner, cost_center y managed_by."
  type        = map(string)

  validation {
    condition     = alltrue([for k in ["env", "app", "owner", "cost_center", "managed_by"] : contains(keys(var.labels), k)])
    error_message = "labels debe incluir env, app, owner, cost_center y managed_by."
  }
}
