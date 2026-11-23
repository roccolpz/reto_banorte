variable "project_id" {
  description = "Proyecto del hub de red (`acme-common-net-hub-xxxx`)."
  type        = string
}

variable "prefix" {
  description = "Prefijo de la empresa para nombres de recursos."
  type        = string
  default     = "acme"
}

variable "subnets" {
  description = "Subredes del hub: región -> CIDR."
  type        = map(string)
  default = {
    us-central1 = "10.0.0.0/24"
    us-east4    = "10.0.1.0/24"
  }

  validation {
    condition     = alltrue([for r in keys(var.subnets) : contains(["us-central1", "us-east4"], r)])
    error_message = "Las regiones permitidas son us-central1 y us-east4."
  }

  validation {
    condition = alltrue([for c in values(var.subnets) : can(cidrhost(c, 0)) && (
      # Sin solape con on-prem 192.168.0.0/16: comparación de rangos como enteros.
      sum([for i, o in split(".", cidrhost(c, 0)) : tonumber(o) * pow(256, 3 - i)]) + pow(2, 32 - tonumber(split("/", c)[1])) <= 3232235520 ||
      sum([for i, o in split(".", cidrhost(c, 0)) : tonumber(o) * pow(256, 3 - i)]) >= 3232235520 + 65536
    )])
    error_message = "Cada subred debe ser un CIDR válido que no se solape con 192.168.0.0/16."
  }
}

variable "corp_dns_domain" {
  description = "Dominio corporativo on-prem que el hub reenvía."
  type        = string
  default     = "corp.acme.internal."

  validation {
    condition     = endswith(var.corp_dns_domain, ".")
    error_message = "corp_dns_domain debe terminar en punto."
  }
}

variable "onprem_dns_target_ips" {
  description = "IPs de los servidores DNS on-prem a los que el hub reenvía `corp_dns_domain`."
  type        = list(string)

  validation {
    condition     = length(var.onprem_dns_target_ips) > 0 && alltrue([for ip in var.onprem_dns_target_ips : can(cidrhost("${ip}/32", 0))])
    error_message = "onprem_dns_target_ips debe tener al menos una IPv4 válida."
  }
}

variable "spoke_projects" {
  description = "Proyectos cuyos VPC spokes se aceptan automáticamente en el grupo edge (proyectos host de cada entorno)."
  type        = list(string)
  default     = []
}

variable "labels" {
  description = "Etiquetas obligatorias del contrato (env, app, owner, cost_center, managed_by)."
  type        = map(string)

  validation {
    condition     = alltrue([for k in ["env", "app", "owner", "cost_center", "managed_by"] : contains(keys(var.labels), k)])
    error_message = "labels debe incluir env, app, owner, cost_center y managed_by."
  }
}
