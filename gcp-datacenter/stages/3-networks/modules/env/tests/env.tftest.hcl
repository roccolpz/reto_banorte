mock_provider "google" {}

# El módulo recibe valores planos; las raíces envs/<env> leen el estado remoto (mismo patrón que 4 y 5).
variables {
  host_project_id       = "acme-dev-net-host-ab12"
  hub_network_self_link = "https://www.googleapis.com/compute/v1/projects/acme-common-net-hub-ab12/global/networks/acme-common-net-hub-vpc"
  ncc_hub_id            = "projects/acme-common-net-hub-ab12/locations/global/hubs/acme-common-net-hub"
  onprem_cidrs          = ["192.168.0.0/16"]
  corp_dns_domain       = "corp.acme.internal."
  labels = {
    env         = "dev"
    app         = "landing-zone"
    owner       = "platform"
    cost_center = "infra"
    managed_by  = "terraform"
  }
}

run "dev_una_region" {
  command = plan

  variables {
    env = "dev"
  }

  assert {
    condition     = output.host_project_id == "acme-dev-net-host-ab12"
    error_message = "El host del entorno es el que pasa la raíz."
  }

  assert {
    condition     = keys(output.subnets) == ["us-central1"] && output.subnets["us-central1"].cidr == "10.10.0.0/20"
    error_message = "dev: solo us-central1 con app 10.10.0.0/20."
  }

  assert {
    condition     = module.spoke.subnets["us-central1"].pods_range_name == "pods" && output.dns_domain == "dev.gcp.acme.internal."
    error_message = "Rangos secundarios y dominio DNS del contrato."
  }

  assert {
    condition     = toset(keys(module.firewall.secure_tag_values)) == toset(["gke-nodes", "vm"])
    error_message = "secure_tag_values debe tener gke-nodes y vm."
  }
}

run "firewall_por_etiqueta_segura" {
  command = plan

  variables {
    env = "dev"
  }

  assert {
    condition     = toset(local.firewall_rules["allow-gke-master"].ranges) == toset(["172.16.10.0/28"]) && local.firewall_rules["allow-gke-master"].target_tags == ["gke-nodes"]
    error_message = "P7: el control plane de GKE (172.16.10.0/28) llega solo a la etiqueta gke-nodes."
  }

  assert {
    condition     = local.firewall_rules["allow-gke-master"].protocols == [{ protocol = "tcp", ports = ["443", "10250"] }]
    error_message = "P7: control plane de GKE solo por TCP 443 y 10250."
  }

  assert {
    condition     = alltrue([for r in values(local.firewall_rules) : r.action == "deny" || length(r.target_tags) > 0])
    error_message = "R8: toda regla allow apunta a etiquetas seguras."
  }

  assert {
    condition     = toset(local.firewall_rules["allow-onprem"].ranges) == toset(["192.168.0.0/16"]) && alltrue([for p in local.firewall_rules["allow-onprem"].protocols : p.protocol == "tcp" && length(p.ports) > 0])
    error_message = "R8: on-prem solo entra por puertos TCP explícitos, no por todos los protocolos."
  }

  assert {
    condition     = toset(local.firewall_rules["deny-other-envs"].ranges) == toset(["10.20.0.0/16", "10.30.0.0/16", "10.31.0.0/16"]) && local.firewall_rules["deny-other-envs"].priority < local.firewall_rules["allow-onprem"].priority
    error_message = "dev bloquea qa y prod antes de cualquier allow."
  }

  assert {
    condition     = local.firewall_rules["deny-all-ingress"].priority == 65000 && local.firewall_rules["deny-all-ingress"].enable_logging
    error_message = "deny-all-ingress al final y con logging."
  }
}

run "prod_dos_regiones" {
  command = plan

  variables {
    env             = "prod"
    host_project_id = "acme-prod-net-host-ab12"
  }

  assert {
    condition     = toset(keys(output.subnets)) == toset(["us-central1", "us-east4"]) && output.subnets["us-east4"].cidr == "10.31.0.0/20"
    error_message = "prod: us-central1 (10.30) y us-east4 (10.31)."
  }

  assert {
    condition     = local.psa_cidr == "10.30.128.0/20"
    error_message = "PSA de prod: 10.30.128.0/20."
  }

  assert {
    condition     = toset(local.deny_cidrs) == toset(["10.10.0.0/16", "10.20.0.0/16"])
    error_message = "prod debe bloquear los rangos de dev y qa."
  }

  assert {
    condition     = toset(local.firewall_rules["allow-gke-master"].ranges) == toset(["172.16.30.0/28", "172.16.31.0/28"])
    error_message = "P7 prod: masters de us-central1 (172.16.30.0/28) y DR us-east4 (172.16.31.0/28)."
  }
}

run "entorno_invalido" {
  command = plan

  variables {
    env = "test"
  }

  expect_failures = [var.env]
}
