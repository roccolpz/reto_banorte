mock_provider "google" {}

override_data {
  target = data.terraform_remote_state.org
  values = {
    outputs = {
      common_project_ids   = { net_hub = "acme-common-net-hub-ab12", logging = "l", security = "s", backup = "b" }
      net_host_project_ids = { dev = "acme-dev-net-host-ab12", qa = "acme-qa-net-host-ab12", prod = "acme-prod-net-host-ab12" }
    }
  }
}

override_data {
  target = data.terraform_remote_state.hub
  values = {
    outputs = {
      hub_project_id        = "acme-common-net-hub-ab12"
      hub_network_id        = "projects/acme-common-net-hub-ab12/global/networks/acme-common-net-hub-vpc"
      hub_network_self_link = "https://www.googleapis.com/compute/v1/projects/acme-common-net-hub-ab12/global/networks/acme-common-net-hub-vpc"
      ncc_hub_id            = "projects/acme-common-net-hub-ab12/locations/global/hubs/acme-common-net-hub"
      onprem_cidrs          = ["192.168.0.0/16"]
      corp_dns_domain       = "corp.acme.internal."
    }
  }
}

variables {
  state_bucket = "acme-tf-state-ab12"
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
    error_message = "El host del entorno sale de net_host_project_ids."
  }

  assert {
    condition     = keys(output.subnets) == ["us-central1"] && output.subnets["us-central1"].cidr == "10.10.0.0/20"
    error_message = "dev: solo us-central1 con app 10.10.0.0/20."
  }

  assert {
    condition     = module.spoke.subnets["us-central1"].pods_range_name == "pods" && output.dns_domain == "dev.gcp.acme.internal."
    error_message = "Rangos secundarios y dominio DNS del contrato."
  }
}

run "prod_dos_regiones" {
  command = plan

  variables {
    env = "prod"
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
}

run "entorno_invalido" {
  command = plan

  variables {
    env = "test"
  }

  expect_failures = [var.env]
}
