mock_provider "google" {}

override_data {
  target = data.terraform_remote_state.bootstrap
  values = {
    outputs = {
      stage_service_accounts = {
        plan              = "sa-tf-plan@seed.iam.gserviceaccount.com"
        "2-security"      = "sa-tf-2-sec@seed.iam.gserviceaccount.com"
        "4-projects-dev"  = "sa-tf-4-proj-dev@seed.iam.gserviceaccount.com"
        "4-projects-qa"   = "sa-tf-4-proj-qa@seed.iam.gserviceaccount.com"
        "4-projects-prod" = "sa-tf-4-proj-prod@seed.iam.gserviceaccount.com"
      }
    }
  }
}

override_data {
  target = data.terraform_remote_state.org
  values = {
    outputs = { common_project_ids = { security = "acme-common-security-ab12" } }
  }
}

variables {
  state_bucket       = "acme-tf-state-ab12"
  suffix             = "ab12"
  access_policy_name = "123456789"
}

run "salidas_y_perimetros" {
  command = plan

  assert {
    condition     = keys(output.kms_keys["prod"]) == ["gke", "sql", "sql-dr", "storage", "storage-us"] && keys(output.kms_keys["dev"]) == ["gke", "sql", "storage"]
    error_message = "kms_keys: dev/qa con storage, sql, gke; prod además sql-dr y storage-us."
  }

  assert {
    condition     = local.keyrings["prod-us"].location == "us" && local.keyrings["prod-us"].keys == ["storage-us"]
    error_message = "storage-us vive en un keyring de la multi-región us (ADR 0002-d)."
  }

  assert {
    condition     = google_secret_manager_secret.secrets["dev/db-app-password"].secret_id == "acme-dev-db-app-password"
    error_message = "Secretos por entorno con prefijo."
  }

  assert {
    condition     = output.perimeter_names["qa"] == "accessPolicies/123456789/servicePerimeters/acme_qa_perimeter"
    error_message = "perimeter_names debe seguir el contrato."
  }

  assert {
    condition     = output.access_policy_name == "123456789"
    error_message = "Debe usarse la política existente por default."
  }

  assert {
    condition     = alltrue([for m in module.perimeter : m.enforced == false])
    error_message = "Los perímetros van en dry-run por default."
  }

  assert {
    condition = local.ingress_identities["dev"] == [
      "serviceAccount:sa-tf-4-proj-dev@seed.iam.gserviceaccount.com",
      "serviceAccount:sa-tf-plan@seed.iam.gserviceaccount.com",
    ]
    error_message = "El ingreso de dev solo admite la SA de plan y las SA de etapa de dev."
  }
}

run "politica_nueva_requiere_org_id" {
  command = plan

  variables {
    create_access_policy = true
  }

  expect_failures = [var.org_id]
}
