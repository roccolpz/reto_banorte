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
    condition = (
      google_kms_key_ring_iam_member.stage_4_projects["dev"].member == "serviceAccount:sa-tf-4-proj-dev@seed.iam.gserviceaccount.com" &&
      google_kms_key_ring_iam_member.stage_4_projects["prod-us"].member == "serviceAccount:sa-tf-4-proj-prod@seed.iam.gserviceaccount.com" &&
      google_kms_key_ring_iam_member.stage_4_projects["prod-dr"].role == "roles/cloudkms.admin"
    )
    error_message = "Cada SA de 4-projects administra el IAM solo de los keyrings de su entorno."
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

run "sin_estado_de_4_projects_no_agrega_proyectos" {
  command = plan

  assert {
    condition     = length(google_access_context_manager_service_perimeter_dry_run_resource.env_projects) == 0
    error_message = "Antes del primer apply de 4-projects no hay proyectos que agregar."
  }
}

run "agrega_proyectos_de_dev_y_qa_desde_4_projects" {
  command = plan

  override_data {
    target = data.google_storage_bucket_objects.projects_state
    values = { bucket_objects = [{ name = "4-projects/dev/default.tfstate", media_link = "", self_link = "", content_type = "", storage_class = "" }] }
  }

  override_data {
    target = data.terraform_remote_state.projects
    values = { outputs = { app_project_number = "111", data_project_number = "222" } }
  }

  assert {
    condition     = toset(keys(google_access_context_manager_service_perimeter_dry_run_resource.env_projects)) == toset(["dev/app", "dev/data", "qa/app", "qa/data"])
    error_message = "2-security agrega app y datos de dev y qa; prod los agrega 4-projects-prod (ADR 0007-f)."
  }

  assert {
    condition = (
      google_access_context_manager_service_perimeter_dry_run_resource.env_projects["dev/app"].resource == "projects/111" &&
      google_access_context_manager_service_perimeter_dry_run_resource.env_projects["qa/data"].perimeter_name == module.perimeter["qa"].name
    )
    error_message = "Cada proyecto entra al perímetro de su entorno por número."
  }

  assert {
    condition     = length(google_access_context_manager_service_perimeter_resource.env_projects) == 0
    error_message = "En dry-run no se toca el status aplicado."
  }
}

run "politica_nueva_requiere_org_id" {
  command = plan

  variables {
    create_access_policy = true
  }

  expect_failures = [var.org_id]
}
