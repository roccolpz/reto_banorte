mock_provider "google" {}
mock_provider "google" {
  alias = "acm"
}
mock_provider "google-beta" {}

variables {
  env             = "prod"
  prefix          = "acme"
  suffix          = "ab12"
  billing_account = "000000-000000-000000"
  folder_id       = "folders/111111111111"
  host_project_id = "acme-prod-net-host-ab12"
  subnets = {
    "us-central1" = { name = "acme-prod-net-app-usc1", self_link = "projects/acme-prod-net-host-ab12/regions/us-central1/subnetworks/acme-prod-net-app-usc1" }
    "us-east4"    = { name = "acme-prod-net-app-use4", self_link = "projects/acme-prod-net-host-ab12/regions/us-east4/subnetworks/acme-prod-net-app-use4" }
  }
  kms_keys = {
    storage  = "projects/acme-common-security-ab12/locations/us-central1/keyRings/kr/cryptoKeys/storage"
    sql      = "projects/acme-common-security-ab12/locations/us-central1/keyRings/kr/cryptoKeys/sql"
    gke      = "projects/acme-common-security-ab12/locations/us-central1/keyRings/kr/cryptoKeys/gke"
    "sql-dr" = "projects/acme-common-security-ab12/locations/us-east4/keyRings/kr-dr/cryptoKeys/sql-dr"
  }
  perimeter_name           = "accessPolicies/123456789/servicePerimeters/acme_prod"
  deployer_service_account = "sa-tf-5-wl-prod@seed.iam.gserviceaccount.com"
  vpc_sc_enforce           = false
  secure_tag_values        = { "gke-nodes" = "tagValues/1001", vm = "tagValues/1002" }
  labels                   = { app = "landing-zone", owner = "platform", cost_center = "infra", env = "prod", managed_by = "terraform" }
  binauthz_attestor = {
    id      = "projects/acme-common-security-ab12/attestors/acme-prod-qa-approved"
    project = "acme-common-security-ab12"
    name    = "acme-prod-qa-approved"
  }
}

run "proyectos_iam_y_perimetro_dry_run" {
  command = plan

  assert {
    condition     = output.app_project_id == "acme-prod-app-ab12" && output.data_project_id == "acme-prod-data-ab12"
    error_message = "Proyectos con el patrón <prefix>-<env>-<dominio>-<suffix>."
  }

  assert {
    condition     = keys(output.service_accounts) == ["app_workload", "gke_nodes", "vm"]
    error_message = "service_accounts debe tener gke_nodes, app_workload y vm."
  }

  assert {
    condition     = keys(google_kms_crypto_key_iam_member.service_agents) == ["gke", "sql", "sql-dr", "storage"]
    error_message = "Cada llave de kms_keys[env] recibe un agente de servicio."
  }

  assert {
    condition     = alltrue([for m in google_kms_crypto_key_iam_member.service_agents : m.role == "roles/cloudkms.cryptoKeyEncrypterDecrypter"])
    error_message = "Los agentes solo reciben cryptoKeyEncrypterDecrypter."
  }

  assert {
    condition     = length(google_compute_subnetwork_iam_member.network_users) == 4
    error_message = "Robot de GKE y cloudservices reciben networkUser en cada subred (2 x 2)."
  }

  assert {
    condition     = length(google_access_context_manager_service_perimeter_dry_run_resource.projects) == 2 && length(google_access_context_manager_service_perimeter_resource.projects) == 0
    error_message = "Con vpc_sc_enforce = false los proyectos entran al spec dry-run."
  }

  assert {
    condition = alltrue([for d in ["app", "data"] :
    contains(keys(google_project_iam_member.deployer), "${d}/roles/monitoring.metricsScopesAdmin")])
    error_message = "La SA de 5-workloads necesita monitoring.metricsScopes.link en app (scoping) y en data (monitoreado)."
  }

  assert {
    condition     = !contains([for b in google_project_iam_member.deployer : b.project], "acme-prod-net-host-ab12")
    error_message = "4-projects no da roles en el host a la SA de 5-workloads: 1-org ya da networkUser en la carpeta (P11)."
  }

  assert {
    condition = toset(keys(google_tags_tag_value_iam_member.secure_tags)) == toset([
      "gke-nodes/deployer/roles/resourcemanager.tagUser",
      "gke-nodes/gke_robot/roles/resourcemanager.tagUser",
      "gke-nodes/gke_robot/roles/resourcemanager.tagHoldAdmin",
      "gke-nodes/cloudservices/roles/resourcemanager.tagUser",
      "vm/deployer/roles/resourcemanager.tagUser",
      "vm/cloudservices/roles/resourcemanager.tagUser",
    ])
    error_message = "Quien liga las etiquetas seguras (SA de 5-workloads, agente de GKE, agente de Google APIs) recibe tagUser; el agente de GKE además tagHoldAdmin."
  }

  assert {
    condition     = google_tags_tag_value_iam_member.secure_tags["vm/deployer/roles/resourcemanager.tagUser"].tag_value == "tagValues/1002"
    error_message = "Los permisos van sobre el valor de etiqueta de 3-networks."
  }

  assert {
    condition     = google_project_iam_member.workload_roles["app_workload/data/roles/cloudsql.client"].project == "acme-prod-data-ab12"
    error_message = "app_workload recibe cloudsql.client en el proyecto de datos."
  }
}

run "perimetro_aplicado" {
  command = plan

  variables {
    vpc_sc_enforce = true
  }

  assert {
    condition     = length(google_access_context_manager_service_perimeter_resource.projects) == 2 && length(google_access_context_manager_service_perimeter_dry_run_resource.projects) == 0
    error_message = "Con vpc_sc_enforce = true los proyectos entran al status aplicado."
  }
}

run "rechaza_etiquetas_seguras_incompletas" {
  command = plan

  variables {
    secure_tag_values = { vm = "tagValues/1002" }
  }

  expect_failures = [var.secure_tag_values]
}

run "entorno_invalido" {
  command = plan

  variables {
    env = "test"
  }

  expect_failures = [var.env]
}

run "perimetro_a_cargo_de_2_security" {
  command = plan

  variables {
    add_to_perimeter = false
  }

  assert {
    condition     = length(google_access_context_manager_service_perimeter_resource.projects) == 0 && length(google_access_context_manager_service_perimeter_dry_run_resource.projects) == 0
    error_message = "Con add_to_perimeter = false (dev, qa) el módulo no toca el perímetro: lo hace 2-security (ADR 0007-f)."
  }
}

run "prod_exige_atestacion_qa_approved" {
  command = plan

  assert {
    condition = (
      google_binary_authorization_policy.this[0].project == "acme-prod-app-ab12" &&
      google_binary_authorization_policy.this[0].default_admission_rule[0].evaluation_mode == "REQUIRE_ATTESTATION" &&
      google_binary_authorization_policy.this[0].default_admission_rule[0].enforcement_mode == "ENFORCED_BLOCK_AND_AUDIT_LOG" &&
      toset(google_binary_authorization_policy.this[0].default_admission_rule[0].require_attestations_by) == toset(["projects/acme-common-security-ab12/attestors/acme-prod-qa-approved"])
    )
    error_message = "El proyecto de app de prod bloquea toda imagen sin la atestación qa-approved (ADR 0022-k)."
  }

  assert {
    condition     = google_binary_authorization_policy.this[0].global_policy_evaluation_mode == "ENABLE"
    error_message = "Las imágenes de sistema de GKE se admiten sin atestación."
  }

  assert {
    condition = (
      google_binary_authorization_attestor_iam_member.verifier[0].role == "roles/binaryauthorization.attestorsVerifier" &&
      google_binary_authorization_attestor_iam_member.verifier[0].attestor == "acme-prod-qa-approved" &&
      google_binary_authorization_attestor_iam_member.verifier[0].project == "acme-common-security-ab12"
    )
    error_message = "Solo el agente de Binary Authorization del proyecto de app recibe attestorsVerifier, sobre el attestor qa-approved."
  }
}

run "dev_sin_politica_de_atestacion" {
  command = plan

  variables {
    env               = "dev"
    binauthz_attestor = null
    labels            = { app = "landing-zone", owner = "platform", cost_center = "infra", env = "dev", managed_by = "terraform" }
  }

  assert {
    condition     = length(google_binary_authorization_policy.this) == 0 && length(google_binary_authorization_attestor_iam_member.verifier) == 0
    error_message = "dev y qa no exigen atestación: la regla de QA aplica a prod."
  }
}

run "prod_sin_attestor_falla" {
  command = plan

  variables {
    binauthz_attestor = null
  }

  expect_failures = [var.binauthz_attestor]
}
