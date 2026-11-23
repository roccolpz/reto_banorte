variable "cluster_name" { type = string }
variable "project_id" { type = string }
variable "region" { type = string }
variable "network" { type = string }
variable "subnetwork" { type = string }
variable "master_ipv4_cidr_block" { type = string }

variable "node_pools" {
  description = "Configuración de pools de nodos"
  type = map(object({
    machine_type = string
    min_count    = number
    max_count    = number
  }))
}

variable "master_authorized_networks" {
  description = "Lista de redes autorizadas para acceder al plano de control de GKE"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}