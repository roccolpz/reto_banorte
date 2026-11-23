variable "name" {
  description = "Prefijo de nombre de la plantilla, el MIG y el health check."
  type        = string
}

variable "project_id" {
  description = "Proyecto de servicio donde se crean las VM."
  type        = string
}

variable "region" {
  description = "Región del MIG regional."
  type        = string
  default     = "us-central1"

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]$", var.region))
    error_message = "region debe ser una región de GCP, p. ej. us-central1."
  }
}

variable "subnetwork" {
  description = "Self link o ID de la subred (Shared VPC) para las VM."
  type        = string
}

variable "service_account_email" {
  description = "Email de la SA dedicada de las VM."
  type        = string
}

variable "machine_type" {
  description = "Tipo de máquina."
  type        = string
  default     = "e2-micro"
}

variable "image_family" {
  description = "Familia de imagen endurecida de arranque (projects/<proyecto>/global/images/family/<familia>); debe soportar Shielded VM. Ver ADR 0018-i."
  type        = string
  default     = "projects/debian-cloud/global/images/family/debian-12"
  nullable    = false

  validation {
    condition     = can(regex("^projects/[a-z][-a-z0-9]{4,28}[a-z0-9]/global/images/family/[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", var.image_family))
    error_message = "image_family debe ser una familia de imagen: projects/<proyecto>/global/images/family/<familia>."
  }
}

variable "min_replicas" {
  description = "Mínimo de VM que mantiene el autoscaler."
  type        = number
  default     = 1

  validation {
    condition     = var.min_replicas >= 1
    error_message = "min_replicas debe ser al menos 1."
  }
}

variable "max_replicas" {
  description = "Máximo de VM que puede crear el autoscaler."
  type        = number
  default     = 3

  validation {
    condition     = var.max_replicas >= var.min_replicas
    error_message = "max_replicas no puede ser menor que min_replicas."
  }
}

variable "cpu_target" {
  description = "Uso de CPU promedio (0-1) que el autoscaler busca mantener."
  type        = number
  default     = 0.6

  validation {
    condition     = var.cpu_target > 0 && var.cpu_target < 1
    error_message = "cpu_target debe estar entre 0 y 1."
  }
}

variable "health_check_port" {
  description = "Puerto TCP que revisa el health check de autocuración (22 = sshd)."
  type        = number
  default     = 22
}

variable "startup_script" {
  description = "Script de arranque opcional (sin secretos)."
  type        = string
  default     = null
}

variable "network_tags" {
  description = "Etiquetas de red para reglas de firewall."
  type        = list(string)
  default     = []
}

variable "resource_manager_tags" {
  description = "Etiquetas seguras de las VM, formato { \"tagKeys/ID\" = \"tagValues/ID\" }. Vacío no etiqueta."
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for k, v in var.resource_manager_tags : startswith(k, "tagKeys/") && startswith(v, "tagValues/")])
    error_message = "resource_manager_tags usa llaves tagKeys/ID y valores tagValues/ID."
  }
}

variable "labels" {
  description = "Etiquetas de las VM. Deben incluir env, app, owner, cost_center y managed_by."
  type        = map(string)

  validation {
    condition     = alltrue([for k in ["env", "app", "owner", "cost_center", "managed_by"] : contains(keys(var.labels), k)])
    error_message = "labels debe incluir env, app, owner, cost_center y managed_by."
  }
}
