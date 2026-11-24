mock_provider "google" {
  mock_data "google_kms_crypto_key_version" {
    defaults = {
      public_key = [{ pem = "-----BEGIN PUBLIC KEY-----\nMFkw\n-----END PUBLIC KEY-----\n", algorithm = "EC_SIGN_P256_SHA256" }]
    }
  }
  mock_resource "google_kms_crypto_key" {
    defaults = {
      id = "projects/acme-common-security-ab12/locations/us-central1/keyRings/acme-prod-keyring-ab12/cryptoKeys/binauthz-qa-approved"
    }
  }
  mock_resource "google_binary_authorization_attestor" {
    defaults = {
      id = "projects/acme-common-security-ab12/attestors/acme-prod-qa-approved"
    }
  }
}

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
        "attestor-prod"   = "sa-binauthz-attestor-prod@seed.iam.gserviceaccount.com"
      }
    }
  }
}

override_data {
  target = data.terraform_remote_state.org
  values = {
    outputs = {
      common_project_ids     = { security = "acme-common-security-ab12" }
      common_project_numbers = { security = "333333333333", backup = "444444444444" }
      custom_role_ids = {
        kms_key_iam_admin   = "organizations/000000000000/roles/kms_key_iam_admin"
        tag_value_iam_admin = "organizations/000000000000/roles/tag_value_iam_admin"
        attestor_iam_admin  = "organizations/000000000000/roles/attestor_iam_admin"
      }
    }
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
      google_kms_key_ring_iam_member.stage_4_projects["prod-dr"].role == "organizations/000000000000/roles/kms_key_iam_admin"
    )
    error_message = "Cada SA de 4-projects administra solo el IAM de las llaves de su entorno, con el rol a medida (P8)."
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
    condition     = alltrue([for m in module.perimeter : m.enforced == false]) && output.vpc_sc_enforce == tomap({ dev = false, qa = false, prod = false })
    error_message = "Los perímetros van en dry-run por default y vpc_sc_enforce se publica por entorno."
  }

  assert {
    condition     = length(google_secret_manager_secret_iam_member.accessors) == 0 && alltrue([for e, r in local.egress_rules : length(r) == 0])
    error_message = "Sin estado de 4-projects no hay identidades de carga: ni accesores de secretos ni egreso."
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
    values = {
      outputs = {
        app_project_number  = "111"
        data_project_number = "222"
        service_accounts = {
          gke_nodes    = "gke-nodes@acme-env-app-ab12.iam.gserviceaccount.com"
          app_workload = "app-workload@acme-env-app-ab12.iam.gserviceaccount.com"
          vm           = "vm@acme-env-app-ab12.iam.gserviceaccount.com"
        }
      }
    }
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

  assert {
    condition = (
      toset(keys(google_secret_manager_secret_iam_member.accessors)) == toset(flatten([
        for e in ["dev", "qa", "prod"] : ["${e}/db-app-password/app_workload", "${e}/db-app-password/vm"]
      ])) &&
      google_secret_manager_secret_iam_member.accessors["prod/db-app-password/vm"].role == "roles/secretmanager.secretAccessor" &&
      google_secret_manager_secret_iam_member.accessors["prod/db-app-password/vm"].member == "serviceAccount:vm@acme-env-app-ab12.iam.gserviceaccount.com"
    )
    error_message = "Solo las SAs de carga app_workload y vm leen los secretos de su entorno (R5)."
  }

  assert {
    condition = local.egress_rules["prod"] == [{
      identities = ["serviceAccount:app-workload@acme-env-app-ab12.iam.gserviceaccount.com"]
      resources  = ["projects/444444444444"]
      services   = ["storage.googleapis.com"]
    }]
    error_message = "El egreso de cada perímetro solo permite a app_workload escribir en el proyecto de respaldo (ADR 0013-g)."
  }
}

run "enforce_por_entorno" {
  command = plan

  variables {
    vpc_sc_enforce = { dev = false, qa = true, prod = true }
  }

  override_data {
    target = data.google_storage_bucket_objects.projects_state
    values = { bucket_objects = [{ name = "4-projects/x/default.tfstate", media_link = "", self_link = "", content_type = "", storage_class = "" }] }
  }

  override_data {
    target = data.terraform_remote_state.projects
    values = { outputs = { app_project_number = "111", data_project_number = "222" } }
  }

  assert {
    condition     = !module.perimeter["dev"].enforced && module.perimeter["qa"].enforced && module.perimeter["prod"].enforced
    error_message = "Cada perímetro se aplica según su entorno (S1)."
  }

  assert {
    condition = (
      toset(keys(google_access_context_manager_service_perimeter_dry_run_resource.env_projects)) == toset(["dev/app", "dev/data"]) &&
      toset(keys(google_access_context_manager_service_perimeter_resource.env_projects)) == toset(["qa/app", "qa/data"])
    )
    error_message = "dev queda en dry-run y qa aplicado; prod lo agrega 4-projects-prod."
  }

  assert {
    condition     = output.vpc_sc_enforce == tomap({ dev = false, qa = true, prod = true })
    error_message = "4-projects lee vpc_sc_enforce de esta salida."
  }
}

run "enforce_requiere_los_tres_entornos" {
  command = plan

  variables {
    vpc_sc_enforce = { dev = true }
  }

  expect_failures = [var.vpc_sc_enforce]
}

run "politica_nueva_requiere_org_id" {
  command = plan

  variables {
    create_access_policy = true
  }

  expect_failures = [var.org_id]
}

run "binary_authorization_attestor_qa_approved" {
  command = apply

  assert {
    condition = (
      google_kms_crypto_key.binauthz_qa.purpose == "ASYMMETRIC_SIGN" &&
      google_kms_crypto_key.binauthz_qa.version_template[0].algorithm == "EC_SIGN_P256_SHA256"
    )
    error_message = "La llave del attestor es asimétrica de firma EC P-256 (ADR 0022-k)."
  }

  assert {
    condition = (
      google_kms_crypto_key_iam_member.binauthz_signer.role == "roles/cloudkms.signerVerifier" &&
      google_kms_crypto_key_iam_member.binauthz_signer.member == "serviceAccount:sa-binauthz-attestor-prod@seed.iam.gserviceaccount.com" &&
      google_kms_crypto_key_iam_member.binauthz_signer.crypto_key_id == google_kms_crypto_key.binauthz_qa.id
    )
    error_message = "Solo attestor-prod firma, y solo con la llave del attestor."
  }

  assert {
    condition     = google_binary_authorization_attestor.qa_approved.attestation_authority_note[0].public_keys[0].id == "//cloudkms.googleapis.com/v1/${google_kms_crypto_key.binauthz_qa.id}/cryptoKeyVersions/1"
    error_message = "El ID de la llave pública del attestor debe coincidir con el que usa scripts/attest-images.sh."
  }

  assert {
    condition = (
      google_binary_authorization_attestor_iam_member.stage_4_projects_prod.role == "organizations/000000000000/roles/attestor_iam_admin" &&
      google_binary_authorization_attestor_iam_member.stage_4_projects_prod.member == "serviceAccount:sa-tf-4-proj-prod@seed.iam.gserviceaccount.com"
    )
    error_message = "4-projects-prod solo administra el IAM del attestor, con el rol a medida."
  }

  assert {
    condition     = output.binauthz_key_version == "${google_kms_crypto_key.binauthz_qa.id}/cryptoKeyVersions/1"
    error_message = "binauthz_key_version apunta a la versión 1 de la llave del attestor."
  }
}
