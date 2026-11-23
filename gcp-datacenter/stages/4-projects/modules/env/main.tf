# single_project (compact_projects de 1-org): app y datos viven en el proyecto del entorno (host_project_id);
# no se crean proyectos ni se adjuntan a la Shared VPC.
data "google_project" "host" {
  count      = var.single_project ? 1 : 0
  project_id = var.host_project_id
}

locals {
  app_project_id  = var.single_project ? var.host_project_id : module.app[0].project_id
  data_project_id = var.single_project ? var.host_project_id : module.data[0].project_id

  app_number  = var.single_project ? data.google_project.host[0].number : module.app[0].project_number
  data_number = var.single_project ? data.google_project.host[0].number : module.data[0].project_number

  gke_robot = "serviceAccount:service-${local.app_number}@container-engine-robot.iam.gserviceaccount.com"
  # Agente de Google APIs: crea las VM de los MIG en la subred compartida.
  cloudservices = "serviceAccount:${local.app_number}@cloudservices.gserviceaccount.com"
}

# --- Proyectos de servicio (Shared VPC) ---

module "app" {
  source = "../../../../modules/project-factory"
  count  = var.single_project ? 0 : 1

  name                       = "${var.prefix} ${var.env} app"
  project_id                 = "${var.prefix}-${var.env}-app-${var.suffix}"
  folder_id                  = var.folder_id
  billing_account            = var.billing_account
  shared_vpc_host_project_id = var.host_project_id
  labels                     = var.labels
  activate_apis = [
    "compute.googleapis.com",
    "container.googleapis.com",
    "binaryauthorization.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
  ]
}

module "data" {
  source = "../../../../modules/project-factory"
  count  = var.single_project ? 0 : 1

  name                       = "${var.prefix} ${var.env} data"
  project_id                 = "${var.prefix}-${var.env}-data-${var.suffix}"
  folder_id                  = var.folder_id
  billing_account            = var.billing_account
  shared_vpc_host_project_id = var.host_project_id
  labels                     = var.labels
  activate_apis = [
    "compute.googleapis.com",
    "sqladmin.googleapis.com",
    "storage.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
  ]
}

# --- Red compartida: permisos de los agentes del proyecto de app ---

resource "google_compute_subnetwork_iam_member" "network_users" {
  for_each = merge([
    for region, s in var.subnets : {
      "${region}/gke_robot"     = { region = region, subnet = s.name, member = local.gke_robot }
      "${region}/cloudservices" = { region = region, subnet = s.name, member = local.cloudservices }
    }
  ]...)

  project    = var.host_project_id
  region     = each.value.region
  subnetwork = each.value.subnet
  role       = "roles/compute.networkUser"
  member     = each.value.member

  depends_on = [module.app]
}

resource "google_project_iam_member" "gke_host_agent" {
  project = var.host_project_id
  role    = "roles/container.hostServiceAgentUser"
  member  = local.gke_robot

  depends_on = [module.app]
}

# --- Cuentas de servicio de cargas (mínimo privilegio) ---

locals {
  workload_sas = {
    gke_nodes    = { account_id = "gke-nodes", display_name = "Nodos GKE ${var.env}" }
    app_workload = { account_id = "app-workload", display_name = "Workload Identity de la app ${var.env}" }
    vm           = { account_id = "vm-instances", display_name = "VM del MIG ${var.env}" }
  }

  workload_roles = {
    gke_nodes = {
      app = [
        "roles/logging.logWriter",
        "roles/monitoring.metricWriter",
        "roles/monitoring.viewer",
        "roles/stackdriver.resourceMetadata.writer",
        "roles/artifactregistry.reader",
      ]
    }
    app_workload = {
      data = ["roles/cloudsql.client", "roles/cloudsql.instanceUser"]
    }
    vm = {
      app = ["roles/logging.logWriter", "roles/monitoring.metricWriter"]
    }
  }

  domain_projects = {
    app  = local.app_project_id
    data = local.data_project_id
  }
}

resource "google_service_account" "workloads" {
  for_each = local.workload_sas

  project      = local.app_project_id
  account_id   = each.value.account_id
  display_name = each.value.display_name
}

resource "google_project_iam_member" "workload_roles" {
  for_each = merge([
    for sa, domains in local.workload_roles : merge([
      for domain, roles in domains : {
        for role in roles : "${sa}/${domain}/${role}" => { sa = sa, project = local.domain_projects[domain], role = role }
      }
    ]...)
  ]...)

  project = each.value.project
  role    = each.value.role
  member  = google_service_account.workloads[each.value.sa].member
}

# --- CMEK: agentes de servicio sobre las llaves del entorno ---

data "google_storage_project_service_account" "data" {
  project = local.data_project_id

  depends_on = [module.data]
}

resource "google_project_service_identity" "sql" {
  provider = google-beta

  project = local.data_project_id
  service = "sqladmin.googleapis.com"

  depends_on = [module.data]
}

locals {
  kms_members = {
    storage = "serviceAccount:${data.google_storage_project_service_account.data.email_address}"
    sql     = "serviceAccount:${google_project_service_identity.sql.email}"
    gke     = local.gke_robot
  }
}

resource "google_kms_crypto_key_iam_member" "service_agents" {
  for_each = var.kms_keys

  crypto_key_id = each.value
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = local.kms_members[regex("^(storage|sql|gke)", each.key)[0]]

  depends_on = [module.app]
}

# --- VPC-SC: app y datos dentro del perímetro del entorno ---

locals {
  perimeter_projects = var.add_to_perimeter ? (var.single_project ? {
    app = "projects/${local.app_number}"
    } : {
    app  = "projects/${local.app_number}"
    data = "projects/${local.data_number}"
  }) : {}
}

resource "google_access_context_manager_service_perimeter_dry_run_resource" "projects" {
  provider = google.acm
  for_each = { for k, v in local.perimeter_projects : k => v if !var.vpc_sc_enforce }

  perimeter_name = var.perimeter_name
  resource       = each.value
}

resource "google_access_context_manager_service_perimeter_resource" "projects" {
  provider = google.acm
  for_each = { for k, v in local.perimeter_projects : k => v if var.vpc_sc_enforce }

  perimeter_name = var.perimeter_name
  resource       = each.value
}

# --- SA de 5-workloads: permisos para desplegar en estos proyectos ---

locals {
  deployer = "serviceAccount:${var.deployer_service_account}"

  # Solo lo que 1-org no otorga ya en la carpeta del entorno (networkUser en el host incluido).
  deployer_roles = {
    app = [
      "roles/compute.loadBalancerAdmin",
      "roles/monitoring.metricsScopesAdmin",
      "roles/logging.configWriter",
    ]
    # data entra al metrics scope de app: el link exige monitoring.metricsScopes.link en ambos proyectos.
    data = [
      "roles/monitoring.metricsScopesAdmin",
    ]
  }

  deployer_project_bindings = merge([
    for domain, roles in local.deployer_roles : {
      for role in roles : "${domain}/${role}" => { project = local.domain_projects[domain], role = role }
    }
  ]...)

  # serviceAccountAdmin solo sobre app_workload: 5-workloads crea el binding de Workload Identity cuando existe el clúster.
  deployer_sa_bindings = {
    gke_nodes    = "roles/iam.serviceAccountUser"
    vm           = "roles/iam.serviceAccountUser"
    app_workload = "roles/iam.serviceAccountAdmin"
  }
}

resource "google_project_iam_member" "deployer" {
  for_each = local.deployer_project_bindings

  project = each.value.project
  role    = each.value.role
  member  = local.deployer
}

resource "google_service_account_iam_member" "deployer" {
  for_each = local.deployer_sa_bindings

  service_account_id = google_service_account.workloads[each.key].name
  role               = each.value
  member             = local.deployer
}

# --- Etiquetas seguras de 3-networks: quién puede ligarlas ---

locals {
  # 5-workloads liga la etiqueta; el agente de GKE la pone en los nodos (y retiene el valor mientras exista el
  # clúster); el agente de Google APIs crea las VM de los MIG y de los pools.
  secure_tag_members = {
    "gke-nodes" = {
      deployer      = ["roles/resourcemanager.tagUser"]
      gke_robot     = ["roles/resourcemanager.tagUser", "roles/resourcemanager.tagHoldAdmin"]
      cloudservices = ["roles/resourcemanager.tagUser"]
    }
    vm = {
      deployer      = ["roles/resourcemanager.tagUser"]
      cloudservices = ["roles/resourcemanager.tagUser"]
    }
  }

  secure_tag_principals = {
    deployer      = local.deployer
    gke_robot     = local.gke_robot
    cloudservices = local.cloudservices
  }
}

resource "google_tags_tag_value_iam_member" "secure_tags" {
  for_each = merge([
    for tag, who in local.secure_tag_members : merge([
      for principal, roles in who : {
        for role in roles : "${tag}/${principal}/${role}" => { tag = tag, principal = principal, role = role }
      }
    ]...)
  ]...)

  tag_value = var.secure_tag_values[each.value.tag]
  role      = each.value.role
  member    = local.secure_tag_principals[each.value.principal]

  depends_on = [module.app]
}
