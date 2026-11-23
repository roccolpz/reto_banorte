variable "env" {
  description = "Entorno: dev, qa o prod."
  type        = string

  validation {
    condition     = contains(["dev", "qa", "prod"], var.env)
    error_message = "env debe ser dev, qa o prod."
  }
}

variable "prefix" {
  description = "Prefijo de la empresa en los nombres."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,9}$", var.prefix))
    error_message = "prefix: minúsculas y números, 2 a 10 caracteres, empieza con letra."
  }
}

variable "suffix" {
  description = "4 caracteres hex que hacen únicos los IDs de proyecto."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{4}$", var.suffix))
    error_message = "suffix debe ser 4 caracteres hexadecimales en minúscula."
  }
}

variable "billing_account" {
  description = "Cuenta de facturación de los proyectos (llega como TF_VAR_billing_account)."
  type        = string
}

variable "folder_id" {
  description = "Folder del entorno (folders/<id>), salida folder_ids de 1-org."
  type        = string
}

variable "host_project_id" {
  description = "Proyecto host de la Shared VPC del entorno (salida de 3-networks/<env>)."
  type        = string
}

variable "subnets" {
  description = "Subredes de la Shared VPC por región (salida subnets de 3-networks/<env>); se usan name y self_link."
  type = map(object({
    name      = string
    self_link = string
  }))

  validation {
    condition     = alltrue([for r in keys(var.subnets) : contains(["us-central1", "us-east4"], r)])
    error_message = "Las regiones de subnets deben ser us-central1 o us-east4."
  }
}

variable "kms_keys" {
  description = "Llaves del entorno, propósito → ID (kms_keys[env] de 2-security). El prefijo del propósito elige el agente: storage*, sql*, gke*."
  type        = map(string)

  validation {
    condition     = alltrue([for p in keys(var.kms_keys) : can(regex("^(storage|sql|gke)", p))])
    error_message = "Cada propósito de kms_keys debe empezar con storage, sql o gke."
  }
}

variable "perimeter_name" {
  description = "Perímetro VPC-SC del entorno (accessPolicies/<n>/servicePerimeters/<nombre>)."
  type        = string
}

variable "add_to_perimeter" {
  description = "true: este módulo agrega app y datos al perímetro (solo prod, cuya SA tiene policyEditor). false: los agrega 2-security (dev, qa; ADR 0007-f)."
  type        = bool
  default     = true
}

variable "vpc_sc_enforce" {
  description = "false agrega los proyectos al spec dry-run del perímetro; true al status aplicado. Viene de vpc_sc_enforce[env] de 2-security."
  type        = bool
  nullable    = false
}

variable "deployer_service_account" {
  description = "SA de 5-workloads del entorno (stage_service_accounts de 0-bootstrap). Recibe los permisos para desplegar en los proyectos."
  type        = string
  nullable    = false
}

variable "secure_tag_values" {
  description = "Valores de las etiquetas seguras del entorno (secure_tag_values de 3-networks/<env>): gke-nodes y vm → tagValues/<id>."
  type        = map(string)

  validation {
    condition     = alltrue([for k in ["gke-nodes", "vm"] : startswith(lookup(var.secure_tag_values, k, ""), "tagValues/")])
    error_message = "secure_tag_values debe tener gke-nodes y vm con valores tagValues/<id>."
  }
}

variable "labels" {
  description = "Etiquetas de los proyectos. Deben incluir env, app, owner, cost_center y managed_by."
  type        = map(string)

  validation {
    condition     = alltrue([for k in ["env", "app", "owner", "cost_center", "managed_by"] : contains(keys(var.labels), k)])
    error_message = "labels debe incluir env, app, owner, cost_center y managed_by."
  }
}

variable "single_project" {
  description = "true: app y datos usan host_project_id (compact_projects de 1-org); no se crean proyectos."
  type        = bool
  default     = false
}
