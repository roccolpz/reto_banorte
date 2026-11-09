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