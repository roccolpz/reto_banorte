# Pruebas de la raíz 0-bootstrap con proveedor simulado: no tocan GCP.
# command = apply con mocks para que los atributos calculados (nombre del pool WIF) tengan valor.
mock_provider "google" {
  # El proveedor valida el formato del nombre de la SA; el mock por defecto genera texto aleatorio.
  mock_resource "google_service_account" {
    defaults = {
      name   = "projects/acme-bootstrap-seed-a1b2/serviceAccounts/sa-tf-mock@acme-bootstrap-seed-a1b2.iam.gserviceaccount.com"
      email  = "sa-tf-mock@acme-bootstrap-seed-a1b2.iam.gserviceaccount.com"
      member = "serviceAccount:sa-tf-mock@acme-bootstrap-seed-a1b2.iam.gserviceaccount.com"
    }
  }
}

# Proveedor del presupuesto (budget.tf).
mock_provider "google" {
  alias = "billing"
}

variables {
  org_id          = "000000000000"
  billing_account = "000000-000000-000000"
  suffix          = "a1b2"
  labels = {
    app         = "landing-zone"
    owner       = "plataforma"
    cost_center = "cc-0000"
  }
}

run "crea_una_sa_por_etapa_y_limita_prod_al_environment_prod" {
  command = apply

  assert {
    condition     = length(output.stage_service_accounts) == 14
    error_message = "Debe haber 14 SA: plan, una por etapa y entorno, y attestor-prod."
  }

  assert {
    condition     = endswith(google_service_account_iam_member.wif["5-workloads-prod"].member, "/attribute.prod_main/true")
    error_message = "Las SA de prod solo se impersonan desde el environment prod de GitHub sobre main."
  }

  assert {
    condition     = endswith(google_service_account_iam_member.wif["attestor-prod"].member, "/attribute.prod_main/true")
    error_message = "La SA que firma imágenes de prod solo se impersona desde el environment prod sobre main (ADR 0022-k)."
  }

  assert {
    condition = (
      !contains(keys(google_storage_bucket_iam_member.state_reader), "attestor-prod") &&
      !contains(keys(google_storage_bucket_iam_member.stage_writer), "attestor-prod") &&
      !anytrue([for b in google_organization_iam_member.stage : strcontains(b.member, "sa-binauthz-attestor-prod")])
    )
    error_message = "attestor-prod no lee ni escribe estado y no tiene roles en la organización."
  }

  assert {
    condition = alltrue([
      for k in ["1-org", "2-security", "3-networks-hub"] :
      endswith(google_service_account_iam_member.wif[k].member, "/attribute.prod_main/true")
    ])
    error_message = "Las SA de etapas comunes (1-org, 2-security, 3-networks-hub) solo se impersonan desde el environment prod sobre main."
  }

  assert {
    condition     = endswith(google_service_account_iam_member.wif["plan"].member, "/attribute.repository/roccolpz/reto_banorte")
    error_message = "La SA de plan se impersona desde cualquier job del repositorio (plan de PR y drift)."
  }

  assert {
    condition     = endswith(google_service_account_iam_member.wif["5-workloads-dev"].member, "/attribute.repository/roccolpz/reto_banorte")
    error_message = "Las SA que no son de prod se impersonan desde el repositorio autorizado."
  }

  assert {
    condition     = google_iam_workload_identity_pool_provider.github.attribute_condition == "assertion.repository == \"roccolpz/reto_banorte\""
    error_message = "WIF debe aceptar solo el repositorio autorizado."
  }

  assert {
    condition     = google_iam_workload_identity_pool_provider.github.attribute_mapping["attribute.prod_main"] == "has(assertion.environment) && assertion.environment == \"prod\" && assertion.ref == \"refs/heads/main\" ? \"true\" : \"false\""
    error_message = "attribute.prod_main es \"true\" solo con environment prod y ref refs/heads/main."
  }
}

run "bucket_de_estado_cifrado_y_escritura_por_prefijo" {
  command = apply

  assert {
    condition     = google_storage_bucket.state.public_access_prevention == "enforced" && google_storage_bucket.state.uniform_bucket_level_access && google_storage_bucket.state.versioning[0].enabled
    error_message = "El bucket de estado debe ser privado, con acceso uniforme y versionado."
  }

  assert {
    condition     = google_storage_bucket.state.location == "US-CENTRAL1" || google_storage_bucket.state.location == "us-central1"
    error_message = "El bucket de estado vive en us-central1."
  }

  assert {
    condition     = google_kms_crypto_key.state.rotation_period == "7776000s"
    error_message = "La llave del estado rota cada 90 días."
  }

  assert {
    condition     = strcontains(google_storage_bucket_iam_member.stage_writer["3-networks-dev"].condition[0].expression, "/objects/3-networks/dev/")
    error_message = "Cada SA escribe solo bajo el prefijo de su etapa."
  }

  assert {
    condition     = !contains(keys(google_storage_bucket_iam_member.stage_writer), "plan")
    error_message = "La SA de plan no puede escribir estado."
  }

  assert {
    condition     = contains(keys(google_storage_bucket_iam_member.state_reader), "plan") && length(google_storage_bucket_iam_member.state_reader["plan"].condition) == 0
    error_message = "La SA de plan lee todo el estado (ADR 0008-g)."
  }
}

run "cada_etapa_lee_solo_los_estados_que_consume" {
  command = apply

  assert {
    condition = (
      strcontains(google_storage_bucket_iam_member.state_reader["5-workloads-dev"].condition[0].expression, "/objects/4-projects/dev/\")") &&
      strcontains(google_storage_bucket_iam_member.state_reader["5-workloads-dev"].condition[0].expression, "/objects/3-networks/hub/\")") &&
      !strcontains(google_storage_bucket_iam_member.state_reader["5-workloads-dev"].condition[0].expression, "/objects/4-projects/prod/") &&
      !strcontains(google_storage_bucket_iam_member.state_reader["5-workloads-dev"].condition[0].expression, "/objects/0-bootstrap/")
    )
    error_message = "5-workloads-dev lee solo los estados de su entorno y de las etapas comunes que consume (R4)."
  }

  assert {
    condition = alltrue([
      for e in ["dev", "qa", "prod"] :
      strcontains(google_storage_bucket_iam_member.state_reader["2-security"].condition[0].expression, "/objects/4-projects/${e}/\")")
    ])
    error_message = "2-security lee el estado de 4-projects de los tres entornos (proyectos, accesores y egreso)."
  }

  assert {
    condition = (
      strcontains(google_storage_bucket_iam_member.state_reader["1-org"].condition[0].expression, "/objects/0-bootstrap/\")") &&
      !strcontains(google_storage_bucket_iam_member.state_reader["1-org"].condition[0].expression, "/objects/2-security/")
    )
    error_message = "1-org solo lee el estado de 0-bootstrap."
  }

  assert {
    condition     = alltrue([for k, m in google_storage_bucket_iam_member.state_reader : strcontains(m.condition[0].expression, "resource.type == \"storage.googleapis.com/Bucket\"") if k != "plan"])
    error_message = "Las etapas pueden listar el bucket (backend gcs y listado de 2-security), pero solo leen objetos de sus prefijos."
  }
}

run "seed_y_roles_para_scc_y_roles_a_medida" {
  command = apply

  assert {
    condition     = contains(local.seed_apis, "pubsub.googleapis.com") && contains(local.seed_apis, "securitycenter.googleapis.com")
    error_message = "1-org crea notificaciones de SCC y su tópico facturando a la semilla."
  }

  assert {
    condition = (
      contains(keys(google_organization_iam_member.stage), "1-org|roles/securitycenter.notificationConfigEditor") &&
      contains(keys(google_organization_iam_member.stage), "1-org|roles/iam.organizationRoleAdmin") &&
      contains(keys(google_organization_iam_member.stage), "plan|roles/securitycenter.notificationConfigViewer")
    )
    error_message = "1-org administra notificaciones de SCC y roles a medida; plan los lee."
  }
}

run "falla_con_sufijo_invalido" {
  command = plan

  variables {
    suffix = "XYZ"
  }

  expect_failures = [var.suffix]
}

run "presupuesto_mensual_con_alertas" {
  command = plan

  assert {
    condition     = google_billing_budget.monthly.amount[0].specified_amount[0].units == "6000" && google_billing_budget.monthly.amount[0].specified_amount[0].currency_code == "MXN"
    error_message = "Presupuesto mensual de 6000 MXN por defecto (moneda de la cuenta de facturación)."
  }

  assert {
    condition     = length(google_billing_budget.monthly.threshold_rules) == 4
    error_message = "Alertas al 50, 90 y 100 % reales y al 100 % pronosticado."
  }

  assert {
    condition     = contains(local.seed_apis, "billingbudgets.googleapis.com")
    error_message = "La semilla habilita la API de presupuestos."
  }
}
