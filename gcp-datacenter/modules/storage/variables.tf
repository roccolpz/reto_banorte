variable "name" {
  description = "Nombre global del bucket (incluye el suffix)."
  type        = string
}

variable "project_id" {
  description = "Proyecto donde se crea el bucket."
  type        = string
}

variable "location" {
  description = "Ubicación del bucket: una región (US-CENTRAL1) o, con dual_region, el multi-región que la contiene (US)."
  type        = string
  default     = "US-CENTRAL1"
}

variable "dual_region" {
  description = "Par de regiones para un dual-region configurable, p. ej. [\"US-CENTRAL1\", \"US-EAST4\"]. Vacío = bucket de una región."
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.dual_region) == 0 || length(var.dual_region) == 2
    error_message = "dual_region debe estar vacío o tener exactamente dos regiones."
  }
}

variable "turbo_replication" {
  description = "true activa turbo replication (rpo = ASYNC_TURBO). Solo válido con dual_region."
  type        = bool
  default     = false

  validation {
    condition     = !var.turbo_replication || length(var.dual_region) == 2
    error_message = "turbo_replication requiere un bucket dual-region (dual_region con dos regiones)."
  }
}

variable "kms_key_name" {
  description = "ID de la llave KMS por defecto del bucket. Debe estar en la misma ubicación que el bucket (p. ej. us-central1, o us para un dual-region en US)."
  type        = string
}

variable "versioning" {
  description = "Activa el versionado de objetos."
  type        = bool
  default     = true
}

variable "lifecycle_rules" {
  description = "Reglas de ciclo de vida. action = Delete o SetStorageClass (con storage_class); condiciones opcionales age, num_newer_versions y with_state."
  type = list(object({
    action             = string
    storage_class      = optional(string)
    age                = optional(number)
    num_newer_versions = optional(number)
    with_state         = optional(string)
  }))
  default = [
    { action = "SetStorageClass", storage_class = "NEARLINE", age = 30 },
    { action = "Delete", num_newer_versions = 5, with_state = "ARCHIVED" },
  ]

  validation {
    condition     = alltrue([for r in var.lifecycle_rules : contains(["Delete", "SetStorageClass"], r.action) && (r.action != "SetStorageClass" || r.storage_class != null)])
    error_message = "Cada regla usa action Delete o SetStorageClass, y SetStorageClass requiere storage_class."
  }
}

variable "force_destroy" {
  description = "Permite borrar el bucket con objetos dentro (útil en dev)."
  type        = bool
  default     = false
}

variable "labels" {
  description = "Etiquetas del bucket. Deben incluir env, app, owner, cost_center y managed_by."
  type        = map(string)

  validation {
    condition     = alltrue([for k in ["env", "app", "owner", "cost_center", "managed_by"] : contains(keys(var.labels), k)])
    error_message = "labels debe incluir env, app, owner, cost_center y managed_by."
  }
}
