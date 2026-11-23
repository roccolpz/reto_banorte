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

variable "source_image" {
  description = "Imagen de arranque (debe soportar Shielded VM)."
  type        = string
  default     = "debian-cloud/debian-12"
}

variable "target_size" {
  description = "Número de VM del MIG."
  type        = number
  default     = 1
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

variable "labels" {
  description = "Etiquetas de las VM. Deben incluir env, app, owner, cost_center y managed_by."
  type        = map(string)

  validation {
    condition     = alltrue([for k in ["env", "app", "owner", "cost_center", "managed_by"] : contains(keys(var.labels), k)])
    error_message = "labels debe incluir env, app, owner, cost_center y managed_by."
  }
}
