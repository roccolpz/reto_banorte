# Pruebas offline (sin credenciales de GCP): se usa un provider simulado.
# Ejecutar desde modules/env-access:  terraform init && terraform test

mock_provider "google" {
  mock_resource "google_service_account" {
    defaults = {
      email = "sa-prod-deployer@acme-host-prod-test.iam.gserviceaccount.com"
      name  = "projects/acme-host-prod-test/serviceAccounts/sa-prod-deployer@acme-host-prod-test.iam.gserviceaccount.com"
    }
  }
}

variables {
  environment         = "prod"
  project_id          = "acme-host-prod-test"
  project_number      = "123456789"
  deployer_account_id = "sa-prod-deployer"
  approvers_group     = "qa-prod-approvers@example.com"
}

run "deployer_gets_only_minimal_roles" {
  command = apply

  assert {
    condition = toset(keys(google_project_iam_member.deployer)) == toset([
      "roles/browser",
      "roles/serviceusage.serviceUsageAdmin",
      "roles/compute.networkAdmin",
      "roles/container.clusterAdmin",
    ])
    error_message = "El deployer tiene roles distintos a los mínimos esperados"
  }

  assert {
    condition = alltrue([
      for m in google_project_iam_member.deployer : !contains(["roles/owner", "roles/editor"], m.role)
    ])
    error_message = "El deployer nunca debe tener owner/editor"
  }

  assert {
    condition     = google_service_account_iam_member.deployer_acts_as_node_sa.service_account_id == "projects/acme-host-prod-test/serviceAccounts/123456789-compute@developer.gserviceaccount.com"
    error_message = "actAs debe limitarse a la SA de los nodos"
  }

  assert {
    condition     = length(google_folder_iam_member.deployer_xpn_admin) == 0 && length(google_access_context_manager_access_policy_iam_member.deployer) == 0
    error_message = "Sin folder/policy no deben crearse permisos extra"
  }
}

run "approvers_are_read_only" {
  command = apply

  assert {
    condition = alltrue([
      for m in google_project_iam_member.approvers_read_only :
      m.member == "group:qa-prod-approvers@example.com" &&
      can(regex("(browser|[Vv]iewer)$", m.role))
    ])
    error_message = "Los aprobadores de QA solo deben tener roles de lectura"
  }

  assert {
    condition = alltrue([
      for m in google_project_iam_member.approvers_read_only :
      !can(regex("(admin|Admin|editor|owner|serviceAccountUser|TokenCreator)", m.role))
    ])
    error_message = "Los aprobadores de QA no deben poder escribir ni suplantar la SA"
  }
}

run "folder_and_policy_scoped_when_enabled" {
  command = apply

  variables {
    shared_vpc_folder_id       = "folders/111"
    grant_access_policy_editor = true
    access_policy_name         = "999"
  }

  assert {
    condition     = google_folder_iam_member.deployer_xpn_admin[0].folder == "folders/111" && google_folder_iam_member.deployer_xpn_admin[0].role == "roles/compute.xpnAdmin"
    error_message = "xpnAdmin debe otorgarse solo en la carpeta del entorno"
  }

  assert {
    condition     = google_access_context_manager_access_policy_iam_member.deployer[0].name == "999"
    error_message = "policyEditor debe otorgarse solo en la Access Policy indicada"
  }
}
