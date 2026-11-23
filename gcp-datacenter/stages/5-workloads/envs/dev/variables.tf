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

variable "primary_region" {
  description = "Región principal de las cargas."
  type        = string
  default     = "us-central1"
}

variable "dr_region" {
  description = "Región de DR: clúster GKE DR, réplica de Cloud SQL y segunda región del bucket."
  type        = string
  default     = "us-east4"
}

variable "enable_dr_cluster" {
  description = "Clúster GKE DR en dr_region. null: true solo en prod."
  type        = bool
  default     = null
}

variable "gke_node_pools" {
  description = "Pools de nodos de GKE. null: los del entorno (dev/qa e2-medium 1-2, prod e2-standard-2 1-3)."
  type = map(object({
    machine_type = string
    min_count    = number
    max_count    = number
  }))
  default = null
}

variable "sql_tier" {
  description = "Tipo de máquina de Cloud SQL. null: el del entorno (dev/qa db-custom-1-3840, prod db-custom-2-7680)."
  type        = string
  default     = null
}

variable "image_family" {
  description = "Familia de imagen endurecida de las VM del MIG. null: Debian 12 público (ADR 0008-i)."
  type        = string
  default     = null
}

variable "uptime_check_host" {
  description = "Host HTTPS público de la aplicación para el uptime check. null no lo crea."
  type        = string
  default     = null
}
