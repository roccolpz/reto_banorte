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
  description = "Proyecto del hub (3-networks/hub); solo prod lo agrega al metrics scope para la alerta de túneles VPN."
  type        = string
}

variable "network_self_link" {
  description = "self_link de la VPC compartida del entorno (3-networks/<env>)."
  type        = string
}

variable "subnets" {
  description = "Subredes app por región (salida subnets de 3-networks/<env>). dev y qa solo tienen us-central1."
  type = map(object({
    self_link           = string
    pods_range_name     = string
    services_range_name = string
  }))
}

variable "primary_region" {
  description = "Región principal: GKE, Cloud SQL, MIG y bucket regional."
  type        = string
  default     = "us-central1"

  validation {
    condition     = contains(keys(var.subnets), var.primary_region)
    error_message = "primary_region debe tener subred en subnets."
  }
}

variable "dr_region" {
  description = "Región de DR: clúster GKE DR, réplica de Cloud SQL y segunda región del bucket."
  type        = string
  default     = "us-east4"

  validation {
    condition     = var.dr_region != var.primary_region
    error_message = "dr_region debe ser distinta de primary_region."
  }
}

variable "enable_dr_cluster" {
  description = "Clúster GKE DR en dr_region. null: true solo en prod."
  type        = bool
  default     = null

  validation {
    condition     = !coalesce(var.enable_dr_cluster, var.env == "prod") || contains(keys(var.subnets), var.dr_region)
    error_message = "enable_dr_cluster requiere una subred en dr_region (solo prod la tiene)."
  }
}

variable "gke_node_pools" {
  description = "Pools de nodos de GKE (también los del clúster DR). null: los del entorno (dev/qa e2-medium 1-2, prod e2-standard-2 1-3)."
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
  description = "Familia de imagen de las VM del MIG. null: el default del módulo compute-mig (ADR 0018-i)."
  type        = string
  default     = null
}

variable "secure_tag_key" {
  description = "Llave de las etiquetas seguras de firewall de la VPC del entorno, formato tagKeys/ID."
  type        = string

  validation {
    condition     = startswith(var.secure_tag_key, "tagKeys/")
    error_message = "secure_tag_key debe tener el formato tagKeys/ID."
  }
}

variable "secure_tag_values" {
  description = "Etiquetas seguras de 3-networks/<env> (secure_tag_values): gke-nodes y vm → tagValues/ID."
  type        = map(string)

  validation {
    condition     = alltrue([for k in ["gke-nodes", "vm"] : startswith(lookup(var.secure_tag_values, k, ""), "tagValues/")])
    error_message = "secure_tag_values debe incluir gke-nodes y vm con formato tagValues/ID."
  }
}

variable "uptime_check_host" {
  description = "Host HTTPS público de la aplicación para el uptime check. null no lo crea."
  type        = string
  default     = null
}

variable "service_accounts" {
  description = "Cuentas de servicio de 4-projects: gke_nodes, app_workload, vm, run → email."
  type        = map(string)

  validation {
    condition     = alltrue([for k in ["gke_nodes", "app_workload", "vm", "run"] : contains(keys(var.service_accounts), k)])
    error_message = "service_accounts debe incluir gke_nodes, app_workload, vm y run."
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
  description = "true crea clústeres GKE regionales (prod); false, zonales en la zona -a de la región."
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
  description = "Réplica de Cloud SQL en dr_region con la llave sql-dr. null: true solo en prod."
  type        = bool
  default     = null

  validation {
    condition     = !coalesce(var.enable_dr_replica, var.env == "prod") || contains(keys(var.kms_keys), "sql-dr")
    error_message = "enable_dr_replica requiere la llave sql-dr en kms_keys (solo prod la tiene)."
  }
}

variable "bucket_dual_region" {
  description = "Bucket dual-region primary_region + dr_region con turbo replication. Requiere la llave storage-us (ADR 0002-d). null: true solo en prod."
  type        = bool
  default     = null

  validation {
    condition     = !coalesce(var.bucket_dual_region, var.env == "prod") || contains(keys(var.kms_keys), "storage-us")
    error_message = "bucket_dual_region requiere la llave storage-us en ubicación us (ADR 0002-d)."
  }
}

variable "enable_load_balancer" {
  description = "Balanceador HTTPS global con Cloud Armor delante de Cloud Run. null: true solo en prod."
  type        = bool
  default     = null
}

variable "lb_domain" {
  description = "Dominio del certificado del balanceador. null: <ip>.nip.io."
  type        = string
  default     = null
}

variable "enable_memorystore" {
  description = "Memorystore for Redis BASIC de 1 GB en el proyecto de datos. null: true solo en prod."
  type        = bool
  default     = null
}

variable "enable_backup_dr" {
  description = "Bóveda y plan diario de Backup and DR (30 días) para Cloud SQL. null: true solo en prod."
  type        = bool
  default     = null
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
