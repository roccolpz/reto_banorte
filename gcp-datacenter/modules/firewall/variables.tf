variable "project_id" {
  description = "Proyecto dueño de la VPC (proyecto host de Shared VPC)."
  type        = string
}

variable "network" {
  description = "Self link de la VPC a la que se asocia la política. Su último segmento es el nombre de la red."
  type        = string
}

variable "name_prefix" {
  description = "Prefijo de los nombres, p. ej. `acme-dev-net`. Política `<name_prefix>-fwp`, reglas `<name_prefix>-fw-<llave>`, llave de etiquetas `<name_prefix>-fw`."
  type        = string
}

variable "secure_tags" {
  description = "Valores de etiqueta segura (propósito GCE_FIREWALL) que se crean bajo la llave `<name_prefix>-fw`, p. ej. `gke-nodes`, `vm`. Las reglas los usan en `target_tags`. Lista vacía = sin llave."
  type        = list(string)
  default     = []
}

variable "rules" {
  description = "Reglas de la política. Llave = sufijo del nombre. `action` es allow o deny; `protocols` lista {protocol, ports}; `target_tags` lista valores de `secure_tags` (vacío = toda la VPC). Las prioridades no se repiten."
  type = map(object({
    description    = optional(string, "")
    direction      = optional(string, "INGRESS")
    action         = optional(string, "allow")
    priority       = optional(number, 1000)
    ranges         = list(string)
    protocols      = optional(list(object({ protocol = string, ports = optional(list(string), []) })), [{ protocol = "all" }])
    target_tags    = optional(list(string), [])
    enable_logging = optional(bool, false)
  }))
  default = {}

  validation {
    condition     = alltrue([for r in values(var.rules) : contains(["INGRESS", "EGRESS"], r.direction) && contains(["allow", "deny"], r.action)])
    error_message = "direction debe ser INGRESS o EGRESS y action allow o deny."
  }

  validation {
    condition     = alltrue([for r in values(var.rules) : r.priority >= 0 && r.priority <= 2147483647])
    error_message = "priority debe estar entre 0 y 2147483647."
  }

  validation {
    condition     = length(distinct([for r in values(var.rules) : r.priority])) == length(var.rules)
    error_message = "priority no se puede repetir dentro de una política de firewall."
  }

  validation {
    condition     = alltrue(flatten([for r in values(var.rules) : [for c in r.ranges : can(cidrhost(c, 0))]]))
    error_message = "ranges debe contener CIDR válidos."
  }

  validation {
    condition     = alltrue(flatten([for r in values(var.rules) : [for t in r.target_tags : contains(var.secure_tags, t)]]))
    error_message = "target_tags solo puede usar valores de secure_tags."
  }
}
