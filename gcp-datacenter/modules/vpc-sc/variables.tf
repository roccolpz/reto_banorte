variable "perimeter_name" {
  description = "Nombre corto del perímetro (letras, números y guion bajo; empieza con letra)."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9_]{0,49}$", var.perimeter_name))
    error_message = "perimeter_name debe empezar con letra y solo llevar letras, números o '_' (máx. 50)."
  }
}

variable "access_policy_name" {
  description = "Número de la política de Access Context Manager (sin el prefijo accessPolicies/)."
  type        = string

  validation {
    condition     = can(regex("^[0-9]+$", var.access_policy_name))
    error_message = "access_policy_name debe ser el número de la política, p. ej. \"123456789\"."
  }
}

variable "restricted_services" {
  description = "Servicios protegidos por el perímetro, p. ej. storage.googleapis.com."
  type        = list(string)

  validation {
    condition     = alltrue([for s in var.restricted_services : can(regex("^[a-z0-9.-]+\\.googleapis\\.com$", s))])
    error_message = "Cada servicio debe tener la forma <api>.googleapis.com."
  }
}

variable "member_projects" {
  description = "Números de proyecto iniciales del perímetro. Después de crear el perímetro se ignoran los cambios: los proyectos se agregan con google_access_context_manager_service_perimeter_resource (aplicado) o google_access_context_manager_service_perimeter_dry_run_resource (dry-run)."
  type        = list(string)
  default     = []
}

variable "enforce" {
  description = "true: la configuración va en status (aplicada). false: va en spec con use_explicit_dry_run_spec (solo dry-run). El default true conserva el comportamiento de la raíz legada test-orchestration; las etapas nuevas pasan var.vpc_sc_enforce (default false)."
  type        = bool
  default     = true
}

variable "ingress_identities" {
  description = "Identidades (serviceAccount:, user:, group:, principal:, principalSet:) que pueden entrar desde cualquier origen a todos los servicios del perímetro. Vacío: sin regla de ingreso."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for i in var.ingress_identities : can(regex("^(serviceAccount|user|group|principal|principalSet):", i))])
    error_message = "Cada identidad debe empezar con serviceAccount:, user:, group:, principal: o principalSet:."
  }
}

variable "egress_identities" {
  description = "Identidades que pueden salir del perímetro hacia cualquier recurso y servicio. Vacío: sin regla de egreso."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for i in var.egress_identities : can(regex("^(serviceAccount|user|group|principal|principalSet):", i))])
    error_message = "Cada identidad debe empezar con serviceAccount:, user:, group:, principal: o principalSet:."
  }
}
