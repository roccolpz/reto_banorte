variable "cluster_name" {
  description = "Nombre del cluster GKE."
  type        = string
}

variable "project_id" {
  description = "Proyecto donde se crea el cluster (proyecto de servicio de la Shared VPC)."
  type        = string
}

variable "region" {
  description = "Región del cluster. Con regional = false se usa la zona <region>-a."
  type        = string

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]$", var.region))
    error_message = "region debe ser una región de GCP, p. ej. us-central1."
  }
}

variable "regional" {
  description = "true crea un cluster regional (prod); false, zonal en la primera zona de la región (dev/qa)."
  type        = bool
  default     = false
}

variable "network" {
  description = "ID o self link de la VPC (en el proyecto host)."
  type        = string
}

variable "subnetwork" {
  description = "ID o self link de la subred de nodos (en el proyecto host)."
  type        = string
}

variable "pods_range_name" {
  description = "Nombre del rango secundario de pods en la subred. null deja que GKE lo cree (no sirve en Shared VPC)."
  type        = string
  default     = null
}

variable "services_range_name" {
  description = "Nombre del rango secundario de services en la subred. null deja que GKE lo cree (no sirve en Shared VPC)."
  type        = string
  default     = null
}

variable "master_ipv4_cidr_block" {
  description = "CIDR /28 del plano de control privado."
  type        = string

  validation {
    condition     = can(cidrhost(var.master_ipv4_cidr_block, 0)) && endswith(var.master_ipv4_cidr_block, "/28")
    error_message = "master_ipv4_cidr_block debe ser un CIDR /28 válido."
  }
}

variable "master_authorized_networks" {
  description = "Lista de redes autorizadas para acceder al plano de control de GKE."
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []

  validation {
    condition     = alltrue([for n in var.master_authorized_networks : can(cidrhost(n.cidr_block, 0))])
    error_message = "Cada cidr_block de master_authorized_networks debe ser un CIDR válido."
  }
}

variable "enable_private_endpoint" {
  description = "true deja el plano de control solo con endpoint privado."
  type        = bool
  default     = false
}

variable "node_pools" {
  description = "Pools de nodos. Llave = nombre del pool. En clusters regionales min/max son por zona."
  type = map(object({
    machine_type = string
    min_count    = number
    max_count    = number
  }))

  validation {
    condition     = length(var.node_pools) > 0 && alltrue([for p in values(var.node_pools) : p.min_count >= 0 && p.min_count <= p.max_count])
    error_message = "node_pools no puede estar vacío y cada pool requiere 0 <= min_count <= max_count."
  }
}

variable "node_service_account" {
  description = "Email de la SA dedicada de los nodos. null usa la SA por defecto de Compute con scopes mínimos (solo legado)."
  type        = string
  default     = null
}

variable "release_channel" {
  description = "Canal de versiones de GKE."
  type        = string
  default     = "REGULAR"

  validation {
    condition     = contains(["RAPID", "REGULAR", "STABLE"], var.release_channel)
    error_message = "release_channel debe ser RAPID, REGULAR o STABLE."
  }
}

variable "enable_workload_identity" {
  description = "Activa Workload Identity (pool <project>.svc.id.goog y metadata GKE en los nodos)."
  type        = bool
  default     = true
}

variable "enable_binary_authorization" {
  description = "Activa Binary Authorization con la política del proyecto (PROJECT_SINGLETON_POLICY_ENFORCE)."
  type        = bool
  default     = true
}

variable "enable_shielded_nodes" {
  description = "Activa Shielded GKE Nodes (secure boot e integrity monitoring)."
  type        = bool
  default     = true
}

variable "database_encryption_key" {
  description = "ID de la llave KMS para cifrar secretos de etcd (misma región que el cluster). null los deja sin CMEK."
  type        = string
  default     = null
}

variable "deletion_protection" {
  description = "Protege el cluster contra terraform destroy."
  type        = bool
  default     = false
}

variable "labels" {
  description = "Etiquetas del cluster y de los nodos. Deben incluir env, app, owner, cost_center y managed_by. Vacío solo se acepta por el legado."
  type        = map(string)
  default     = {}

  validation {
    condition     = length(var.labels) == 0 || alltrue([for k in ["env", "app", "owner", "cost_center", "managed_by"] : contains(keys(var.labels), k)])
    error_message = "labels debe incluir env, app, owner, cost_center y managed_by."
  }
}
