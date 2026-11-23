# Módulo local compartido por envs/{dev,qa,prod}: los entornos solo difieren en var.env.
# No lee estado remoto: las raíces envs/<env> leen 1-org y 3-networks/hub y pasan valores planos.

locals {
  # Segundo octeto por entorno y región (contrato §5).
  octets = {
    dev  = { us-central1 = 10 }
    qa   = { us-central1 = 20 }
    prod = { us-central1 = 30, us-east4 = 31 }
  }

  regions = {
    for region, x in local.octets[var.env] : region => {
      app_cidr      = "10.${x}.0.0/20"
      services_cidr = "10.${x}.32.0/22"
      proxy_cidr    = "10.${x}.48.0/23"
      pods_cidr     = "10.${x}.64.0/18"
    }
  }

  # PSA es global a la VPC: un solo rango, con el octeto de us-central1.
  psa_cidr = "10.${local.octets[var.env]["us-central1"]}.128.0/20"

  own_cidrs  = [for x in values(local.octets[var.env]) : "10.${x}.0.0/16"]
  deny_cidrs = flatten([for e, m in local.octets : [for x in values(m) : "10.${x}.0.0/16"] if e != var.env])

  # Etiquetas seguras: gke-nodes (nodos de GKE) y vm (Compute Engine). "workloads" = ambas.
  workloads = ["gke-nodes", "vm"]

  # Reglas de la política de red (R8). Toda regla allow apunta a etiquetas seguras.
  firewall_rules = {
    deny-other-envs = {
      description    = "Aislamiento lateral: niega tráfico desde otros entornos."
      action         = "deny"
      priority       = 900
      ranges         = local.deny_cidrs
      protocols      = [{ protocol = "all", ports = [] }]
      target_tags    = []
      enable_logging = true
    }
    allow-gke-master = {
      description    = "Control plane de GKE (172.16.<octeto>.0/28) hacia los nodos: webhooks y kubelet."
      action         = "allow"
      priority       = 1000
      ranges         = [for x in values(local.octets[var.env]) : "172.16.${x}.0/28"]
      protocols      = [{ protocol = "tcp", ports = ["443", "10250"] }]
      target_tags    = ["gke-nodes"]
      enable_logging = false
    }
    allow-internal = {
      description    = "Tráfico interno del entorno (subredes, pods, services, PSA)."
      action         = "allow"
      priority       = 1010
      ranges         = local.own_cidrs
      protocols      = [{ protocol = "all", ports = [] }]
      target_tags    = local.workloads
      enable_logging = false
    }
    # On-prem solo inicia hacia las apps por HTTP/HTTPS; lo que va de GCP a on-prem (e2e) es
    # tráfico de salida y su respuesta entra por estado de conexión, sin regla de ingreso.
    allow-onprem = {
      description    = "Usuarios corporativos on-prem hacia las apps (HTTP/HTTPS)."
      action         = "allow"
      priority       = 1020
      ranges         = var.onprem_cidrs
      protocols      = [{ protocol = "tcp", ports = ["80", "443"] }]
      target_tags    = local.workloads
      enable_logging = true
    }
    allow-iap = {
      description    = "SSH/RDP por IAP TCP forwarding."
      action         = "allow"
      priority       = 1030
      ranges         = ["35.235.240.0/20"]
      protocols      = [{ protocol = "tcp", ports = ["22", "3389"] }]
      target_tags    = local.workloads
      enable_logging = true
    }
    allow-health-checks = {
      description    = "Health checks de los balanceadores de Google."
      action         = "allow"
      priority       = 1040
      ranges         = ["130.211.0.0/22", "35.191.0.0/16"]
      protocols      = [{ protocol = "tcp", ports = [] }]
      target_tags    = local.workloads
      enable_logging = false
    }
    deny-all-ingress = {
      description    = "Niega todo el ingreso no permitido explícitamente."
      action         = "deny"
      priority       = 65000
      ranges         = ["0.0.0.0/0"]
      protocols      = [{ protocol = "all", ports = [] }]
      target_tags    = []
      enable_logging = true
    }
  }
}

module "spoke" {
  source = "../../../../modules/network-spoke"

  project_id            = var.host_project_id
  prefix                = var.prefix
  env                   = var.env
  regions               = local.regions
  psa_cidr              = local.psa_cidr
  corp_dns_domain       = var.corp_dns_domain
  hub_network_self_link = var.hub_network_self_link
  ncc_hub_id            = var.ncc_hub_id
  labels                = var.labels
}

module "firewall" {
  source = "../../../../modules/firewall"

  project_id  = var.host_project_id
  network     = module.spoke.network_self_link
  name_prefix = "${var.prefix}-${var.env}-net"
  secure_tags = local.workloads
  rules       = local.firewall_rules
  labels      = var.labels
}
