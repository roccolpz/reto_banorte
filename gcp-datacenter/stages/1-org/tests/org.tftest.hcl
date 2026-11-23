# Pruebas de la raíz 1-org con proveedor simulado y estado de 0-bootstrap simulado: no tocan GCP.
mock_provider "google" {
  mock_resource "google_folder" {
    defaults = {
      name      = "folders/111111111111"
      folder_id = "111111111111"
    }
  }
  mock_resource "google_logging_organization_sink" {
    defaults = {
      writer_identity = "serviceAccount:o000000000000-000000@gcp-sa-logging.iam.gserviceaccount.com"
    }
  }
}

override_data {
  target = data.terraform_remote_state.bootstrap
  values = {
    outputs = {
      seed_project_id     = "acme-bootstrap-seed-a1b2"
      bootstrap_folder_id = "folders/999999999999"
      stage_service_accounts = {
        "plan"             = "sa-tf-plan@acme-bootstrap-seed-a1b2.iam.gserviceaccount.com"
        "1-org"            = "sa-tf-1-org@acme-bootstrap-seed-a1b2.iam.gserviceaccount.com"
        "2-security"       = "sa-tf-2-sec@acme-bootstrap-seed-a1b2.iam.gserviceaccount.com"
        "3-networks-hub"   = "sa-tf-3-net-hub@acme-bootstrap-seed-a1b2.iam.gserviceaccount.com"
        "3-networks-dev"   = "sa-tf-3-net-dev@acme-bootstrap-seed-a1b2.iam.gserviceaccount.com"
        "3-networks-qa"    = "sa-tf-3-net-qa@acme-bootstrap-seed-a1b2.iam.gserviceaccount.com"
        "3-networks-prod"  = "sa-tf-3-net-prod@acme-bootstrap-seed-a1b2.iam.gserviceaccount.com"
        "4-projects-dev"   = "sa-tf-4-proj-dev@acme-bootstrap-seed-a1b2.iam.gserviceaccount.com"
        "4-projects-qa"    = "sa-tf-4-proj-qa@acme-bootstrap-seed-a1b2.iam.gserviceaccount.com"
        "4-projects-prod"  = "sa-tf-4-proj-prod@acme-bootstrap-seed-a1b2.iam.gserviceaccount.com"
        "5-workloads-dev"  = "sa-tf-5-wl-dev@acme-bootstrap-seed-a1b2.iam.gserviceaccount.com"
        "5-workloads-qa"   = "sa-tf-5-wl-qa@acme-bootstrap-seed-a1b2.iam.gserviceaccount.com"
        "5-workloads-prod" = "sa-tf-5-wl-prod@acme-bootstrap-seed-a1b2.iam.gserviceaccount.com"
      }
    }
  }
}

variables {
  org_id          = "000000000000"
  billing_account = "000000-000000-000000"
  state_bucket    = "acme-bootstrap-tfstate-a1b2"
  suffix          = "a1b2"
  labels = {
    app         = "landing-zone"
    owner       = "plataforma"
    cost_center = "cc-0000"
  }
}

run "jerarquia_y_salidas_del_contrato" {
  command = apply

  assert {
    condition     = toset(keys(output.folder_ids)) == toset(["bootstrap", "common", "dev", "qa", "prod"])
    error_message = "folder_ids debe tener bootstrap, common, dev, qa y prod."
  }

  assert {
    condition     = output.folder_ids["bootstrap"] == "folders/999999999999"
    error_message = "La carpeta bootstrap se lee de 0-bootstrap, no se crea."
  }

  assert {
    condition     = toset(keys(output.common_project_ids)) == toset(["net_hub", "logging", "security", "backup"])
    error_message = "common_project_ids debe tener net_hub, logging, security y backup."
  }

  assert {
    condition     = output.net_host_project_ids["prod"] == "acme-prod-net-host-a1b2"
    error_message = "Los proyectos net-host siguen el patrón <prefix>-<env>-net-host-<suffix>."
  }

  assert {
    condition     = output.common_project_ids["net_hub"] == "acme-common-net-hub-a1b2"
    error_message = "Los proyectos de common siguen el patrón <prefix>-common-<dominio>-<suffix>."
  }
}

run "org_policies_y_firewall_jerarquico" {
  command = apply

  assert {
    condition     = google_org_policy_policy.list_deny_all["compute.vmExternalIpAccess"].spec[0].rules[0].deny_all == "TRUE"
    error_message = "Las VM no pueden tener IP pública."
  }

  assert {
    condition     = google_org_policy_policy.boolean["iam.disableServiceAccountKeyCreation"].spec[0].rules[0].enforce == "TRUE"
    error_message = "Se prohíbe crear llaves de SA."
  }

  assert {
    condition     = toset(google_org_policy_policy.resource_locations.spec[0].rules[0].values[0].allowed_values) == toset(["in:us-central1-locations", "in:us-east4-locations", "us", "US"])
    error_message = "Solo se permiten us-central1, us-east4 y la multi-región us (bucket dual-region y su llave, ADR 0002-d)."
  }

  assert {
    condition     = length(google_org_policy_policy.allowed_domains) == 0
    error_message = "Sin dominios configurados no se crea iam.allowedPolicyMemberDomains."
  }

  assert {
    condition     = google_compute_firewall_policy_rule.rules["allow-iap"].match[0].src_ip_ranges == tolist(["35.235.240.0/20"])
    error_message = "IAP entra solo desde 35.235.240.0/20."
  }

  assert {
    condition     = google_compute_firewall_policy_rule.rules["goto-next-ingress"].action == "goto_next"
    error_message = "El resto del tráfico se delega a las reglas de cada VPC."
  }

  assert {
    condition     = length(local.group_bindings) == 0
    error_message = "Sin grupos no se crean bindings."
  }

  assert {
    condition     = google_folder_iam_member.this["5-workloads-prod|folder|prod|roles/container.admin"].member == "serviceAccount:sa-tf-5-wl-prod@acme-bootstrap-seed-a1b2.iam.gserviceaccount.com"
    error_message = "La SA de 5-workloads-prod administra GKE solo en la carpeta prod."
  }

  assert {
    condition     = contains(keys(google_project_iam_member.this), "3-networks-hub|project|net_hub|roles/networkconnectivity.hubAdmin")
    error_message = "La SA de 3-networks-hub crea el hub de NCC y su grupo edge."
  }

  assert {
    condition = alltrue([for k in [
      "3-networks-prod|project|net-host-prod|roles/networkconnectivity.spokeAdmin",
      "3-networks-prod|project|net_hub|roles/networkconnectivity.groupUser",
    ] : contains(keys(google_project_iam_member.this), k)])
    error_message = "La SA de 3-networks-<env> crea su spoke en net-host y lo une al grupo edge del hub."
  }

  assert {
    condition     = contains(keys(google_project_iam_member.this), "5-workloads-dev|project|net_hub|roles/monitoring.metricsScopesAdmin")
    error_message = "La SA de 5-workloads-<env> agrega net_hub a su metrics scope."
  }

  assert {
    condition     = length([for k in keys(google_folder_iam_member.this) : k if startswith(k, "5-workloads-dev|folder|prod|")]) == 0
    error_message = "La SA de dev no recibe roles en la carpeta prod."
  }
}

run "auditoria_con_retencion_no_bloqueada_por_defecto" {
  command = apply

  assert {
    condition     = google_storage_bucket.audit.retention_policy[0].is_locked == false
    error_message = "Bloquear la retención es irreversible: default false."
  }

  assert {
    condition     = google_logging_organization_sink.audit.include_children == true
    error_message = "El sink agrega los logs de todo el árbol."
  }

  assert {
    condition     = output.audit_log_bucket == google_storage_bucket.audit.name
    error_message = "audit_log_bucket expone el bucket de auditoría."
  }
}

run "grupos_y_dominios_cuando_se_configuran" {
  command = apply

  variables {
    groups = {
      org_admins     = "gcp-org-admins@example.com"
      billing_admins = "gcp-billing-admins@example.com"
      auditors       = "gcp-auditors@example.com"
    }
    allowed_policy_member_customer_ids = ["C00000000"]
    audit_retention_locked             = true
  }

  assert {
    condition     = contains(keys(local.group_bindings), "org_admins|org|org|roles/resourcemanager.organizationAdmin")
    error_message = "gcp-org-admins administra la organización."
  }

  assert {
    condition     = length([for k, b in local.iam_bindings : k if b.scope == "billing"]) == 0
    error_message = "La SA de 1-org solo tiene billing.user: el rol billing.admin del grupo se otorga a mano."
  }

  assert {
    condition     = contains(keys(local.group_bindings), "billing_admins|org|org|roles/billing.viewer")
    error_message = "gcp-billing-admins ve la facturación desde la organización."
  }

  assert {
    condition     = length([for k, b in local.group_bindings : k if b.group == "developers"]) == 0
    error_message = "Grupos no configurados no reciben bindings."
  }

  assert {
    condition     = length(google_org_policy_policy.allowed_domains) == 1
    error_message = "Con dominios configurados se restringen los miembros de IAM."
  }

  assert {
    condition     = google_storage_bucket.audit.retention_policy[0].is_locked == true
    error_message = "audit_retention_locked bloquea la retención."
  }
}

run "falla_con_grupo_desconocido" {
  command = plan

  variables {
    groups = { admins = "x@example.com" }
  }

  expect_failures = [var.groups]
}
