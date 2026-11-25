variable "name" {
  description = "Nombre del servicio de Cloud Run."
  type        = string
}

variable "project_id" {
  description = "Proyecto donde se crea el servicio."
  type        = string
}

variable "region" {
  description = "Región del servicio."
  type        = string
  default     = "us-central1"
}

variable "image" {
  description = "Imagen del contenedor."
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}

variable "service_account_email" {
  description = "Cuenta de servicio con la que corre el servicio (mínimo privilegio, no la de Compute por defecto)."
  type        = string
}

variable "ingress" {
  description = "Ingreso permitido: INGRESS_TRAFFIC_INTERNAL_ONLY o INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER. Nunca ALL."
  type        = string
  default     = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"

  validation {
    condition     = contains(["INGRESS_TRAFFIC_INTERNAL_ONLY", "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"], var.ingress)
    error_message = "ingress debe ser INGRESS_TRAFFIC_INTERNAL_ONLY o INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER."
  }
}

variable "invoker_iam_disabled" {
  description = "true permite invocar sin roles/run.invoker; el acceso lo limita el ingreso."
  type        = bool
  default     = true
}

variable "min_instances" {
  description = "Instancias mínimas (0 = escala a cero, sin costo en reposo)."
  type        = number
  default     = 0
}

variable "max_instances" {
  description = "Instancias máximas."
  type        = number
  default     = 2

  validation {
    condition     = var.max_instances >= var.min_instances && var.max_instances > 0
    error_message = "max_instances debe ser mayor que cero y >= min_instances."
  }
}

variable "cpu" {
  description = "Límite de CPU por instancia."
  type        = string
  default     = "1"
}

variable "memory" {
  description = "Límite de memoria por instancia."
  type        = string
  default     = "512Mi"
}

variable "deletion_protection" {
  description = "Impide borrar el servicio con Terraform."
  type        = bool
  default     = false
}

variable "labels" {
  description = "Etiquetas. Deben incluir env, app, owner, cost_center y managed_by."
  type        = map(string)

  validation {
    condition     = alltrue([for k in ["env", "app", "owner", "cost_center", "managed_by"] : contains(keys(var.labels), k)])
    error_message = "labels debe incluir env, app, owner, cost_center y managed_by."
  }
}
