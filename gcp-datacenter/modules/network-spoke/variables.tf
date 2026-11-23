variable "project_id" {
  description = "Proyecto host de Shared VPC del entorno (`acme-<env>-net-host-xxxx`)."
  type        = string
}

variable "prefix" {
  description = "Prefijo de la empresa para nombres de recursos."
  type        = string
  default     = "acme"
}

variable "env" {
  description = "Entorno: dev, qa o prod."
  type        = string

  validation {
    condition     = contains(["dev", "qa", "prod"], var.env)
    error_message = "env debe ser dev, qa o prod."
  }
}

variable "regions" {
  description = "Rangos por región: subred app, secundarios `services` y `pods`, y subred proxy-only."
  type = map(object({
    app_cidr      = string
    services_cidr = string
    proxy_cidr    = string
    pods_cidr     = string
  }))

  validation {
    condition     = length(var.regions) > 0 && alltrue([for r in keys(var.regions) : contains(["us-central1", "us-east4"], r)])
    error_message = "Las regiones permitidas son us-central1 y us-east4."
  }

  validation {
    # Dos CIDR se solapan si coinciden al prefijo más corto; try() da false si el CIDR no es válido.
    condition = alltrue(flatten([for r in values(var.regions) : [for c in [r.app_cidr, r.services_cidr, r.proxy_cidr, r.pods_cidr] :
    try(cidrhost("${cidrhost(c, 0)}/${min(16, split("/", c)[1])}", 0) != cidrhost("192.168.0.0/${min(16, split("/", c)[1])}", 0), false)]]))
    error_message = "Cada rango debe ser un CIDR válido que no se solape con 192.168.0.0/16."
  }
}

variable "psa_cidr" {
  description = "Rango para Private Service Access (Cloud SQL, etc.). null = sin PSA."
  type        = string
  default     = null

  validation {
    condition = var.psa_cidr == null ? true : try(cidrhost("${cidrhost(var.psa_cidr, 0)}/${min(16, split("/", var.psa_cidr)[1])}", 0) != cidrhost("192.168.0.0/${min(16, split("/", var.psa_cidr)[1])}", 0), false)
    error_message = "psa_cidr debe ser un CIDR válido que no se solape con 192.168.0.0/16."
  }
}

variable "flow_sampling" {
  description = "Muestreo de VPC flow logs en las subredes app (0 a 1)."
  type        = number
  default     = 0.5

  validation {
    condition     = var.flow_sampling >= 0 && var.flow_sampling <= 1
    error_message = "flow_sampling debe estar entre 0 y 1."
  }
}

variable "enable_shared_vpc_host" {
  description = "Habilita el proyecto como host de Shared VPC."
  type        = bool
  default     = true
}

variable "dns_domain" {
  description = "Dominio de la zona privada del entorno. null = `<env>.gcp.<prefix>.internal.`."
  type        = string
  default     = null

  validation {
    condition     = var.dns_domain == null ? true : endswith(var.dns_domain, ".")
    error_message = "dns_domain debe terminar en punto."
  }
}

variable "corp_dns_domain" {
  description = "Dominio corporativo que se resuelve por DNS peering hacia el hub."
  type        = string
  default     = "corp.acme.internal."
}

variable "hub_network_self_link" {
  description = "Self link de la VPC del hub. Si no es null, se crea la zona de DNS peering de `corp_dns_domain` hacia el hub."
  type        = string
  default     = null
}

variable "ncc_hub_id" {
  description = "ID del hub de NCC. Si no es null, la VPC se registra como VPC spoke en el grupo `edge`."
  type        = string
  default     = null
}

variable "labels" {
  description = "Etiquetas obligatorias del contrato (env, app, owner, cost_center, managed_by)."
  type        = map(string)

  validation {
    condition     = alltrue([for k in ["env", "app", "owner", "cost_center", "managed_by"] : contains(keys(var.labels), k)])
    error_message = "labels debe incluir env, app, owner, cost_center y managed_by."
  }
}
