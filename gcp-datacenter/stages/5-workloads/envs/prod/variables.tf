variable "state_bucket" {
  description = "Bucket GCS del estado de Terraform (salida state_bucket de 0-bootstrap)."
  type        = string
}

variable "prefix" {
  description = "Prefijo de la empresa en los nombres."
  type        = string
  default     = "acme"
}

variable "labels" {
  description = "Etiquetas base; env y managed_by las agrega la raíz."
  type        = map(string)
  default = {
    app         = "landing-zone"
    owner       = "platform"
    cost_center = "infra"
  }

  validation {
    condition     = alltrue([for k in ["app", "owner", "cost_center"] : contains(keys(var.labels), k)])
    error_message = "labels debe incluir app, owner y cost_center."
  }
}

variable "regional" {
  description = "Clúster GKE regional. null: true solo en prod."
  type        = bool
  default     = null
}

variable "deletion_protection" {
  description = "Protección contra borrado de GKE y Cloud SQL. null: true solo en prod."
  type        = bool
  default     = null
}

variable "sql_ha" {
  description = "Cloud SQL en alta disponibilidad. null: true solo en prod."
  type        = bool
  default     = null
}

variable "enable_dr_replica" {
  description = "Réplica de Cloud SQL en us-east4 (solo prod tiene la llave sql-dr). null: true solo en prod."
  type        = bool
  default     = null
}

variable "bucket_dual_region" {
  description = "Bucket dual-region con turbo replication. Requiere la llave storage-us (ADR 0002-d). null: true solo en prod."
  type        = bool
  default     = null
}

variable "notification_email" {
  description = "Correo que recibe las alertas de monitoreo."
  type        = string
}

variable "ksa_namespace" {
  description = "Namespace de la cuenta de Kubernetes vinculada a app_workload."
  type        = string
  default     = "app"
}

variable "ksa_name" {
  description = "Cuenta de Kubernetes vinculada a app_workload."
  type        = string
  default     = "app"
}

variable "master_authorized_networks" {
  description = "Redes autorizadas para el plano de control de GKE."
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}
