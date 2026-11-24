variable "org_id" { type = string }
variable "billing_account" { type = string }
variable "prod_folder_id" { type = string }
variable "dev_folder_id" { type = string }
variable "primary_region" {
  type    = string
  default = "us-central1"
}

variable "suffix" {
  type        = string
  description = "Sufijo aleatorio o único para evitar colisiones en nombres de proyectos"
}

variable "master_authorized_networks" {
  description = "Lista de redes autorizadas para acceder al plano de control de GKE"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}

variable "qa_approvers_group" {
  description = "Correo del Google Group con los usuarios de QA autorizados a aprobar pases a Prod (ej. qa-prod-approvers@tu-dominio.com)"
  type        = string
}

output "prod_deployer_email" {
  description = "Cuenta de servicio que desplegará a Prod desde el pipeline"
  value       = module.access_prod.deployer_email
}
