mock_provider "google" {}
mock_provider "google-beta" {}
mock_provider "random" {}

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
  target = data.google_compute_addresses.onprem_dns
  values = {
    addresses = [{ address = "192.168.10.2", name = "dns-forwarder", region = "us-central1", self_link = "x", labels = {}, address_type = "INTERNAL", project = "acme-common-net-hub-ab12", status = "IN_USE" }]
  }
}

variables {
  state_bucket = "acme-tf-state-ab12"
}

run "hub_onprem_y_vpn" {
  command = plan

  assert {
    condition     = output.hub_project_id == "acme-common-net-hub-ab12"
    error_message = "El hub vive en common_project_ids.net_hub."
  }

  assert {
    condition     = tolist(output.onprem_cidrs) == tolist(["192.168.0.0/16"]) && output.corp_dns_domain == "corp.acme.internal."
    error_message = "Salidas on-prem del contrato §6."
  }

  assert {
    condition     = google_compute_subnetwork.onprem.ip_cidr_range == "192.168.10.0/24" && google_compute_subnetwork.onprem.region == "us-central1"
    error_message = "onprem-sim: subred 192.168.10.0/24 en us-central1."
  }

  assert {
    condition     = google_dns_record_set.onprem_test.name == "app.corp.acme.internal." && google_dns_record_set.onprem_test.rrdatas == tolist(["192.168.10.10"])
    error_message = "Debe existir el registro A de prueba en corp.acme.internal."
  }

  assert {
    condition     = keys(module.vpn) == ["us-central1"]
    error_message = "Por default solo hay VPN en us-central1."
  }

  assert {
    condition     = module.hub.corp_forwarding_zone_name != null
    error_message = "El hub debe reenviar corp.acme.internal."
  }
}

run "vpn_en_dos_regiones" {
  command = plan

  variables {
    vpn_regions = ["us-central1", "us-east4"]
  }

  assert {
    condition     = length(module.vpn) == 2
    error_message = "Una VPN por región de vpn_regions."
  }
}

run "region_vpn_invalida" {
  command = plan

  variables {
    vpn_regions = ["europe-west1"]
  }

  expect_failures = [var.vpn_regions]
}
