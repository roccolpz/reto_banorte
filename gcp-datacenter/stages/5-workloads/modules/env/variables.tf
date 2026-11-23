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
}

variable "app_project_id" {
  description = "Proyecto de aplicación (salida de 4-projects): GKE, MIG y observabilidad."
  type        = string
}

variable "data_project_id" {
  description = "Proyecto de datos (salida de 4-projects): Cloud SQL y bucket."
  type        = string
}

variable "hub_project_id" {
  description = "Proyecto del hub (3-networks/hub); se agrega al metrics scope para la alerta de túneles VPN."
  type        = string
}

variable "network_self_link" {
  description = "self_link de la VPC compartida del entorno (3-networks/<env>)."
  type        = string
}

variable "subnet" {
  description = "Subred app de us-central1 (subnets[\"us-central1\"] de 3-networks/<env>)."
  type = object({
    self_link           = string
    pods_range_name     = string
    services_range_name = string
  })
}

variable "service_accounts" {
  description = "Cuentas de servicio de 4-projects: gke_nodes, app_workload, vm → email."
  type        = map(string)

  validation {
    condition     = alltrue([for k in ["gke_nodes", "app_workload", "vm"] : contains(keys(var.service_accounts), k)])
    error_message = "service_accounts debe incluir gke_nodes, app_workload y vm."
  }
}

variable "kms_keys" {
  description = "Llaves del entorno, propósito → ID (kms_keys[env] de 2-security)."
  type        = map(string)

  validation {
    condition     = alltrue([for k in ["storage", "sql", "gke"] : contains(keys(var.kms_keys), k)])
    error_message = "kms_keys debe incluir storage, sql y gke."
  }
}

variable "regional" {
  description = "true crea un clúster GKE regional (prod); false, zonal en us-central1-a."
  type        = bool
  default     = false
}

variable "master_authorized_networks" {
  description = "Redes autorizadas para el plano de control de GKE."
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}

variable "sql_ha" {
  description = "Cloud SQL en alta disponibilidad regional. null: true solo en prod."
  type        = bool
  default     = null
}

variable "enable_dr_replica" {
  description = "Réplica de Cloud SQL en us-east4 con la llave sql-dr. null: true solo en prod."
  type        = bool
  default     = null

  validation {
    condition     = !coalesce(var.enable_dr_replica, var.env == "prod") || contains(keys(var.kms_keys), "sql-dr")
    error_message = "enable_dr_replica requiere la llave sql-dr en kms_keys (solo prod la tiene)."
  }
}

variable "bucket_dual_region" {
  description = "Bucket dual-region US-CENTRAL1 + US-EAST4 con turbo replication. Requiere la llave storage-us (ADR 0002-d). null: true solo en prod."
  type        = bool
  default     = null

  validation {
    condition     = !coalesce(var.bucket_dual_region, var.env == "prod") || contains(keys(var.kms_keys), "storage-us")
    error_message = "bucket_dual_region requiere la llave storage-us en ubicación us (ADR 0002-d)."
  }
}

variable "deletion_protection" {
  description = "Protección contra borrado de GKE y Cloud SQL; false también permite vaciar el bucket al destruir."
  type        = bool
  default     = false
}

variable "notification_email" {
  description = "Correo que recibe las alertas."
  type        = string
}

variable "ksa_namespace" {
  description = "Namespace de Kubernetes de la cuenta que usa app_workload por Workload Identity."
  type        = string
  default     = "app"
}

variable "ksa_name" {
  description = "Nombre de la cuenta de servicio de Kubernetes que usa app_workload."
  type        = string
  default     = "app"
}

variable "labels" {
  description = "Etiquetas. Deben incluir env, app, owner, cost_center y managed_by."
  type        = map(string)

  validation {
    condition     = alltrue([for k in ["env", "app", "owner", "cost_center", "managed_by"] : contains(keys(var.labels), k)])
    error_message = "labels debe incluir env, app, owner, cost_center y managed_by."
  }
}
