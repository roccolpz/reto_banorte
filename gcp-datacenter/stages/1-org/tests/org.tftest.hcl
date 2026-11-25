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
        "attestor-prod"    = "sa-binauthz-attestor-prod@acme-bootstrap-seed-a1b2.iam.gserviceaccount.com"
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
    condition     = toset(google_org_policy_policy.resource_locations.spec[0].rules[0].values[0].allowed_values) == toset(["in:us-central1-locations", "in:us-east4-locations", "us"])
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
    condition = (
      contains(keys(google_organization_iam_member.this), "4-projects-prod|org|org|roles/accesscontextmanager.policyEditor") &&
      length([for k in keys(google_organization_iam_member.this) : k if strcontains(k, "accesscontextmanager.policyEditor") && !startswith(k, "4-projects-prod|")]) == 0
    )
    error_message = "Solo 4-projects-prod edita perímetros: la política de acceso guarda también el de prod (ADR 0007-f)."
  }

  assert {
    condition     = length([for k in keys(google_folder_iam_member.this) : k if startswith(k, "5-workloads-dev|folder|prod|")]) == 0
    error_message = "La SA de dev no recibe roles en la carpeta prod."
  }

  assert {
    condition     = length([for k in keys(google_folder_iam_member.this) : k if startswith(k, "5-workloads-") && endswith(k, "|roles/iam.serviceAccountUser")]) == 0
    error_message = "5-workloads no recibe serviceAccountUser sobre toda la carpeta: 4-projects lo da por SA (P10)."
  }
}

run "roles_a_medida_y_tags_seguros" {
  command = apply

  assert {
    condition = output.custom_role_ids == {
      kms_key_iam_admin   = "organizations/000000000000/roles/kms_key_iam_admin"
      tag_value_iam_admin = "organizations/000000000000/roles/tag_value_iam_admin"
      attestor_iam_admin  = "organizations/000000000000/roles/attestor_iam_admin"
      redis_auth_reader   = "organizations/000000000000/roles/redis_auth_reader"
    }
    error_message = "custom_role_ids expone los tres roles a medida como organizations/<id>/roles/<nombre> (CONTRATO §6)."
  }

  assert {
    condition = toset(google_organization_iam_custom_role.this["kms_key_iam_admin"].permissions) == toset([
      "cloudkms.cryptoKeys.get", "cloudkms.cryptoKeys.getIamPolicy", "cloudkms.cryptoKeys.setIamPolicy",
    ])
    error_message = "kms_key_iam_admin solo administra el IAM de las llaves, sin crear ni destruir versiones (P8)."
  }

  assert {
    condition = toset(google_organization_iam_custom_role.this["tag_value_iam_admin"].permissions) == toset([
      "resourcemanager.tagValues.get", "resourcemanager.tagValues.getIamPolicy", "resourcemanager.tagValues.setIamPolicy",
    ])
    error_message = "tag_value_iam_admin solo administra el IAM de los valores de tag."
  }

  assert {
    condition     = google_project_iam_member.this["3-networks-dev|project|net-host-dev|roles/resourcemanager.tagAdmin"].project == "acme-dev-net-host-a1b2"
    error_message = "3-networks-<env> crea las llaves y valores de tag seguros en su net-host."
  }

  assert {
    condition     = contains(local.net_host_apis, "cloudresourcemanager.googleapis.com")
    error_message = "Los net-host habilitan Resource Manager: los tags seguros GCE_FIREWALL viven ahí."
  }

  assert {
    condition     = google_project_iam_member.this["4-projects-prod|project|net-host-prod|organizations/000000000000/roles/tag_value_iam_admin"].member == "serviceAccount:sa-tf-4-proj-prod@acme-bootstrap-seed-a1b2.iam.gserviceaccount.com"
    error_message = "4-projects-<env> concede tagUser sobre los valores de tag de su net-host con el rol a medida."
  }

  assert {
    condition     = toset(keys(output.common_project_numbers)) == toset(["net_hub", "logging", "security", "backup"])
    error_message = "common_project_numbers da el número de cada proyecto de common (destino de egreso de VPC-SC)."
  }
}

run "notificaciones_de_scc" {
  command = apply

  assert {
    condition     = google_pubsub_topic.scc_findings.project == "acme-common-security-a1b2"
    error_message = "El tópico de hallazgos de SCC vive en el proyecto de seguridad."
  }

  assert {
    condition     = google_scc_v2_organization_notification_config.findings.pubsub_topic == google_pubsub_topic.scc_findings.id
    error_message = "La notificación de SCC publica en el tópico de hallazgos."
  }

  assert {
    condition     = google_scc_v2_organization_notification_config.findings.organization == "000000000000" && google_scc_v2_organization_notification_config.findings.streaming_config[0].filter == "state = \"ACTIVE\""
    error_message = "Se notifican los hallazgos activos de toda la organización."
  }

  assert {
    condition     = google_pubsub_subscription.scc_findings.topic == google_pubsub_topic.scc_findings.id
    error_message = "Una suscripción retiene los hallazgos para quien los consuma."
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
      break_glass    = "gcp-break-glass@example.com"
      billing_admins = "gcp-billing-admins@example.com"
      auditors       = "gcp-auditors@example.com"
    }
    allowed_policy_member_customer_ids = ["C00000000"]
    audit_retention_locked             = true
  }

  assert {
    condition = (
      contains(keys(local.group_bindings), "break_glass|org|org|roles/resourcemanager.organizationAdmin") &&
      !contains(keys(local.group_bindings), "org_admins|org|org|roles/resourcemanager.organizationAdmin") &&
      contains(keys(local.group_bindings), "org_admins|org|org|roles/resourcemanager.organizationViewer")
    )
    error_message = "gcp-org-admins lee la organización; el acceso de administración es de emergencia, en break_glass (ADR 0009-g)."
  }

  assert {
    condition     = contains(keys(local.group_bindings), "auditors|org|org|roles/securitycenter.findingsViewer")
    error_message = "gcp-auditors consulta los hallazgos de SCC."
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

run "grupos_humanos_solo_leen_fuera_de_break_glass" {
  command = plan

  variables {
    groups = {
      org_admins      = "gcp-org-admins@example.com"
      break_glass     = "gcp-break-glass@example.com"
      billing_admins  = "gcp-billing-admins@example.com"
      security_admins = "gcp-security-admins@example.com"
      network_admins  = "gcp-network-admins@example.com"
      devops          = "gcp-devops@example.com"
      developers      = "gcp-developers@example.com"
      auditors        = "gcp-auditors@example.com"
      qa_approvers    = "gcp-qa-approvers@example.com"
    }
  }

  # Roles de escritura que la revisión encontró en grupos que solo "revisan" (Fase 3 §3.2).
  assert {
    condition = length([for k, b in local.group_bindings : k if b.group != "break_glass" && contains([
      "roles/resourcemanager.organizationAdmin", "roles/resourcemanager.folderAdmin", "roles/orgpolicy.policyAdmin",
      "roles/securitycenter.admin", "roles/cloudkms.admin", "roles/compute.networkAdmin", "roles/container.admin",
      "roles/compute.instanceAdmin.v1", "roles/container.developer",
    ], b.role)]) == 0
    error_message = "Solo break_glass recibe roles de escritura; los cambios ordinarios van por pull request."
  }

  assert {
    condition = alltrue([for g in ["devops", "developers"] : alltrue([for e in ["dev", "qa", "prod"] :
    contains(keys(local.group_bindings), "${g}|folder|${e}|roles/viewer")])])
    error_message = "gcp-devops y gcp-developers leen los tres entornos."
  }

  assert {
    condition     = contains(keys(local.group_bindings), "security_admins|org|org|roles/securitycenter.adminViewer")
    error_message = "gcp-security-admins revisa SCC sin administrarlo."
  }

  # qa_approvers: solo lectura, solo en qa y prod (ADR 0020-k).
  assert {
    condition     = alltrue([for k, b in local.group_bindings : b.scope == "folder" && contains(["qa", "prod"], b.key) if b.group == "qa_approvers"])
    error_message = "gcp-qa-approvers solo recibe roles en las carpetas qa y prod (nada en dev, la organización ni proyectos)."
  }

  assert {
    condition     = alltrue([for k, b in local.group_bindings : can(regex("^roles/(browser|[a-z]+\\.[a-zA-Z]*[Vv]iewer)$", b.role)) if b.group == "qa_approvers"])
    error_message = "gcp-qa-approvers solo recibe roles de lectura: la aprobación ocurre en GitHub, no en GCP."
  }

  assert {
    condition     = alltrue([for e in ["qa", "prod"] : contains(keys(local.group_bindings), "qa_approvers|folder|${e}|roles/container.clusterViewer")])
    error_message = "gcp-qa-approvers ve los clústeres de qa y prod para verificar lo que aprueba."
  }
}

run "falla_con_grupo_desconocido" {
  command = plan

  variables {
    groups = { admins = "x@example.com" }
  }

  expect_failures = [var.groups]
}

run "binary_authorization_minimo_privilegio" {
  command = plan

  # La SA firmante solo recibe roles en el proyecto de seguridad, y ninguno de administración (ADR 0022-k).
  assert {
    condition = toset([for k, b in local.stage_sa_bindings : b.role if startswith(k, "attestor-prod|")]) == toset([
      "roles/containeranalysis.notes.attacher",
      "roles/containeranalysis.occurrences.editor",
    ]) && alltrue([for k, b in local.stage_sa_bindings : b.scope == "project" && b.key == "security" if startswith(k, "attestor-prod|")])
    error_message = "attestor-prod solo adjunta atestaciones en el proyecto de seguridad (la llave la da 2-security)."
  }

  assert {
    condition = (
      contains(keys(local.stage_sa_bindings), "4-projects-prod|folder|prod|roles/binaryauthorization.policyEditor") &&
      !contains(keys(local.stage_sa_bindings), "4-projects-dev|folder|dev|roles/binaryauthorization.policyEditor") &&
      !contains(keys(local.stage_sa_bindings), "4-projects-qa|folder|qa|roles/binaryauthorization.policyEditor")
    )
    error_message = "Solo 4-projects-prod edita la política de Binary Authorization, y solo en la carpeta prod."
  }

  assert {
    condition     = toset(google_organization_iam_custom_role.this["attestor_iam_admin"].permissions) == toset(["binaryauthorization.attestors.get", "binaryauthorization.attestors.getIamPolicy", "binaryauthorization.attestors.setIamPolicy"])
    error_message = "attestor_iam_admin solo administra el IAM del attestor, sin crearlo ni cambiar su llave."
  }

  assert {
    condition     = contains(keys(local.stage_sa_bindings), "2-security|project|security|roles/binaryauthorization.attestorsAdmin")
    error_message = "2-security crea el attestor qa-approved en el proyecto de seguridad."
  }
}
