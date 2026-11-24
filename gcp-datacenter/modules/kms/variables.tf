variable "project_id" {
  description = "Proyecto donde vive el keyring (normalmente acme-common-security-<suffix>)."
  type        = string
}

variable "location" {
  description = "Región del keyring, p. ej. us-central1 o us-east4, o la multi-región us (CMEK de buckets dual-region)."
  type        = string

  validation {
    condition     = can(regex("^([a-z]+-[a-z]+[0-9]+|us)$", var.location))
    error_message = "location debe ser una región de GCP, p. ej. us-central1, o la multi-región us."
  }
}

variable "keyring_name" {
  description = "Nombre del keyring. Debe llevar el suffix: los keyrings no se pueden borrar en GCP y el nombre no se puede reutilizar."
  type        = string
}

variable "keys" {
  description = "Llaves por propósito (storage, sql, gke, ...). rotation_period en segundos, máx. 90 días (7776000s). encrypter_decrypters: miembros IAM (p. ej. agentes de servicio de GCS, Cloud SQL, GKE) con roles/cloudkms.cryptoKeyEncrypterDecrypter."
  type = map(object({
    rotation_period      = optional(string, "7776000s")
    encrypter_decrypters = optional(list(string), [])
  }))

  validation {
    condition = alltrue([
      for k in values(var.keys) :
      can(regex("^[0-9]+s$", k.rotation_period)) && try(tonumber(trimsuffix(k.rotation_period, "s")) >= 86400 && tonumber(trimsuffix(k.rotation_period, "s")) <= 7776000, false)
    ])
    error_message = "rotation_period debe estar entre 86400s (1 día) y 7776000s (90 días)."
  }
}

variable "labels" {
  description = "Etiquetas obligatorias: env, app, owner, cost_center, managed_by."
  type        = map(string)

  validation {
    condition     = alltrue([for k in ["env", "app", "owner", "cost_center", "managed_by"] : contains(keys(var.labels), k)])
    error_message = "labels debe incluir env, app, owner, cost_center y managed_by."
  }
}
