variable "name" {
  description = "Nombre descriptivo del proyecto"
  type        = string
}

variable "project_id" {
  description = "ID único del proyecto en GCP"
  type        = string
}

variable "folder_id" {
  description = "ID de la carpeta contenedora (ej. dev, qa, prod)"
  type        = string
}

variable "billing_account" {
  description = "ID de la cuenta de facturación de GCP"
  type        = string
}

variable "shared_vpc_host_project_id" {
  description = "ID del proyecto Host de la Shared VPC"
  type        = string
  default     = ""
}

variable "activate_apis" {
  description = "Lista de APIs de Google APIs a habilitar"
  type        = list(string)
  default     = ["compute.googleapis.com", "container.googleapis.com"]
}

variable "labels" {
  description = "Etiquetas obligatorias del recurso"
  type        = map(string)
  default     = {}
}