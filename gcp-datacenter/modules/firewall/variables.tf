variable "project_id" {
  description = "Proyecto dueño de la VPC (proyecto host de Shared VPC)."
  type        = string
}

variable "network" {
  description = "Self link o nombre de la VPC a la que se aplican las reglas."
  type        = string
}

variable "name_prefix" {
  description = "Prefijo de los nombres de regla, p. ej. `acme-dev-net`. Cada regla se llama `<name_prefix>-fw-<llave>`."
  type        = string
}

variable "labels" {
  description = "Etiquetas obligatorias del contrato. Las reglas de firewall no aceptan etiquetas; se validan para mantener la interfaz común de módulos."
  type        = map(string)

  validation {
    condition     = alltrue([for k in ["env", "app", "owner", "cost_center", "managed_by"] : contains(keys(var.labels), k)])
    error_message = "labels debe incluir env, app, owner, cost_center y managed_by."
  }
}

variable "default_rules" {
  description = "Si es true, crea el juego base de un entorno: deny-all de ingreso con logging, IAP, health checks de GCP, on-prem y deny explícito desde otros entornos."
  type        = bool
  default     = false
}

variable "onprem_cidrs" {
  description = "Rangos on-prem permitidos por el juego base."
  type        = list(string)
  default     = ["192.168.0.0/16"]

  validation {
    condition     = alltrue([for c in var.onprem_cidrs : can(cidrhost(c, 0))])
    error_message = "onprem_cidrs debe contener CIDR válidos."
  }
}

variable "deny_source_cidrs" {
  description = "Rangos de otros entornos que se bloquean de forma explícita (aislamiento lateral). Lista vacía = sin regla."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for c in var.deny_source_cidrs : can(cidrhost(c, 0))])
    error_message = "deny_source_cidrs debe contener CIDR válidos."
  }
}

variable "rules" {
  description = "Reglas adicionales. Llave = sufijo del nombre. `action` es allow o deny; `protocols` lista {protocol, ports}."
  type = map(object({
    description    = optional(string, "")
    direction      = optional(string, "INGRESS")
    action         = optional(string, "allow")
    priority       = optional(number, 1000)
    ranges         = list(string)
    protocols      = optional(list(object({ protocol = string, ports = optional(list(string), []) })), [{ protocol = "all" }])
    target_tags    = optional(list(string))
    enable_logging = optional(bool, false)
  }))
  default = {}

  validation {
    condition     = alltrue([for r in values(var.rules) : contains(["INGRESS", "EGRESS"], r.direction) && contains(["allow", "deny"], r.action)])
    error_message = "direction debe ser INGRESS o EGRESS y action allow o deny."
  }

  validation {
    condition     = alltrue([for r in values(var.rules) : r.priority >= 0 && r.priority <= 65535])
    error_message = "priority debe estar entre 0 y 65535."
  }

  validation {
    condition     = alltrue(flatten([for r in values(var.rules) : [for c in r.ranges : can(cidrhost(c, 0))]]))
    error_message = "ranges debe contener CIDR válidos."
  }
}
