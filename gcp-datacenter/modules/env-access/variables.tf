variable "environment" {
  description = "Nombre del entorno (prod, test, dev). Solo se usa en descripciones."
  type        = string
}

variable "project_id" {
  description = "Proyecto donde vive el entorno y donde se crea la cuenta de despliegue"
  type        = string
}

variable "project_number" {
  description = "Número del proyecto (para ubicar la cuenta de servicio por defecto de Compute que usan los nodos de GKE)"
  type        = string
}

# ------------------------------------------------------------------
# QUIÉN DESPLIEGA: cuenta de servicio dedicada (no una persona)
# ------------------------------------------------------------------

variable "deployer_account_id" {
  description = "ID de la cuenta de servicio de despliegue (6-30 caracteres)"
  type        = string
}

variable "deployer_project_roles" {
  description = "Roles mínimos que necesita Terraform para administrar los recursos del entorno"
  type        = list(string)
  default = [
    "roles/browser",                        # leer el proyecto (resourcemanager.projects.get)
    "roles/serviceusage.serviceUsageAdmin", # habilitar APIs (google_project_service)
    "roles/compute.networkAdmin",           # VPC y subred
    "roles/container.clusterAdmin",         # clúster GKE y node pools (sin RBAC dentro del clúster)
  ]
}

variable "shared_vpc_folder_id" {
  description = "Carpeta del entorno. Si se define, el deployer recibe compute.xpnAdmin SOLO en esa carpeta (necesario para el Shared VPC host)."
  type        = string
  default     = ""
}

variable "grant_access_policy_editor" {
  description = "Si es true, el deployer puede editar perímetros VPC-SC dentro de access_policy_name"
  type        = bool
  default     = false
}

variable "access_policy_name" {
  description = "Nombre (ID numérico) de la Access Policy de VPC-SC"
  type        = string
  default     = ""
}

# ------------------------------------------------------------------
# QUIÉN APRUEBA: grupo de QA, solo lectura en GCP
# ------------------------------------------------------------------

variable "approvers_group" {
  description = "Correo del Google Group de aprobadores de QA (ej. qa-prod-approvers@tu-dominio.com)"
  type        = string
}

variable "approver_project_roles" {
  description = "Roles de SOLO LECTURA para que los aprobadores verifiquen lo desplegado. Nunca roles de escritura."
  type        = list(string)
  default = [
    "roles/browser",
    "roles/container.clusterViewer",
    "roles/logging.viewer",
    "roles/monitoring.viewer",
  ]
}
