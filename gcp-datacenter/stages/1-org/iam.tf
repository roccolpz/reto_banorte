# IAM de grupos humanos (Fase 3, §3.2) y de las SAs de las etapas 2 a 5.
# Cada binding se identifica como "<principal>|<tipo de alcance>|<llave del alcance>|<rol>".
# Tipos de alcance: org, folder (common/dev/qa/prod), project (llave de local.project_ids),
# y audit_bucket. El rol billing.admin del grupo billing_admins se otorga a mano en la cuenta de
# facturación: la SA de 1-org solo tiene billing.user, sin billing.accounts.setIamPolicy.

locals {
  stage_sas = data.terraform_remote_state.bootstrap.outputs.stage_service_accounts

  project_ids = merge(
    local.common_project_ids,
    { for e, p in module.net_host_project : "net-host-${e}" => p.project_id },
  )

  # Roles por grupo. Solo se aplican los grupos presentes en var.groups. Los grupos ordinarios solo leen: los
  # cambios van por pull request y los aplican las SAs de etapa. break_glass tiene la administración de emergencia;
  # su membresía queda vacía fuera de un incidente y cada alta se audita (ADR 0009-g).
  group_roles = {
    org_admins = [
      { scope = "org", key = "org", role = "roles/resourcemanager.organizationViewer" },
      { scope = "org", key = "org", role = "roles/resourcemanager.folderViewer" },
      { scope = "org", key = "org", role = "roles/orgpolicy.policyViewer" },
      { scope = "org", key = "org", role = "roles/iam.securityReviewer" },
    ]
    break_glass = [
      { scope = "org", key = "org", role = "roles/resourcemanager.organizationAdmin" },
      { scope = "org", key = "org", role = "roles/resourcemanager.folderAdmin" },
      { scope = "org", key = "org", role = "roles/orgpolicy.policyAdmin" },
    ]
    billing_admins = [
      { scope = "org", key = "org", role = "roles/billing.viewer" },
    ]
    security_admins = [
      { scope = "org", key = "org", role = "roles/iam.securityReviewer" },
      { scope = "org", key = "org", role = "roles/securitycenter.adminViewer" },
      { scope = "org", key = "org", role = "roles/orgpolicy.policyViewer" },
      { scope = "org", key = "org", role = "roles/accesscontextmanager.policyReader" },
      { scope = "project", key = "security", role = "roles/cloudkms.viewer" },
    ]
    network_admins = [
      { scope = "org", key = "org", role = "roles/compute.networkViewer" },
      { scope = "org", key = "org", role = "roles/dns.reader" },
    ]
    devops = [
      { scope = "folder", key = "dev", role = "roles/viewer" },
      { scope = "folder", key = "qa", role = "roles/viewer" },
      { scope = "folder", key = "prod", role = "roles/viewer" },
    ]
    developers = [
      { scope = "folder", key = "dev", role = "roles/viewer" },
      { scope = "folder", key = "qa", role = "roles/viewer" },
      { scope = "folder", key = "prod", role = "roles/viewer" },
    ]
    auditors = [
      { scope = "org", key = "org", role = "roles/iam.securityReviewer" },
      { scope = "org", key = "org", role = "roles/logging.privateLogViewer" },
      { scope = "org", key = "org", role = "roles/browser" },
      { scope = "org", key = "org", role = "roles/securitycenter.findingsViewer" },
      { scope = "audit_bucket", key = "audit", role = "roles/storage.objectViewer" },
    ]
    # Usuarios de QA que aprueban los pases a prod (ADR 0020-k). Su aprobación ocurre en GitHub (pull request y
    # environment prod), no en GCP: aquí solo leen qa (lo que validaron) y prod (lo que aprueban), sin dev y sin
    # roles/viewer, que abarca todos los servicios. Nada de escritura ni de suplantar SAs.
    qa_approvers = flatten([for e in ["qa", "prod"] : [
      { scope = "folder", key = e, role = "roles/browser" },
      { scope = "folder", key = e, role = "roles/container.clusterViewer" },
      { scope = "folder", key = e, role = "roles/logging.viewer" },
      { scope = "folder", key = e, role = "roles/monitoring.viewer" },
    ]])
  }

  # Roles a medida (P8 y tags seguros): solo administran el IAM del recurso, sin crearlo ni destruirlo.
  custom_roles = {
    kms_key_iam_admin = {
      title       = "KMS key IAM admin"
      permissions = ["cloudkms.cryptoKeys.get", "cloudkms.cryptoKeys.getIamPolicy", "cloudkms.cryptoKeys.setIamPolicy"]
    }
    tag_value_iam_admin = {
      title       = "Tag value IAM admin"
      permissions = ["resourcemanager.tagValues.get", "resourcemanager.tagValues.getIamPolicy", "resourcemanager.tagValues.setIamPolicy"]
    }
    # 4-projects-prod da attestorsVerifier al agente de Binary Authorization de su proyecto de app sobre el attestor
    # qa-approved, sin poder crearlo, cambiar su llave ni borrarlo (ADR 0022-k).
    attestor_iam_admin = {
      title       = "Binary Authorization attestor IAM admin"
      permissions = ["binaryauthorization.attestors.get", "binaryauthorization.attestors.getIamPolicy", "binaryauthorization.attestors.setIamPolicy"]
    }
    # El refresh de Memorystore con AUTH lee el AUTH string; roles/viewer no lo incluye y sin él falla el plan de los PR
    # y el drift. El valor ya está en el estado que la SA de plan puede leer: no expone nada nuevo (ADR 0023).
    redis_auth_reader = {
      title       = "Memorystore AUTH string reader"
      permissions = ["redis.instances.getAuthString"]
    }
  }
  # Nombre armado aquí y no leído del recurso: las llaves de for_each deben conocerse en el plan.
  custom_role_ids = { for k, _ in local.custom_roles : k => "${local.org}/roles/${k}" }

  group_bindings = {
    for b in flatten([
      for g, email in var.groups : [
        for r in local.group_roles[g] : {
          id     = "${g}|${r.scope}|${r.key}|${r.role}"
          group  = g
          member = "group:${email}"
          scope  = r.scope
          key    = r.key
          role   = r.role
        }
      ]
    ]) : b.id => b
  }

  # Roles de las SAs de etapa. 1-org y plan reciben los suyos en 0-bootstrap.
  stage_sa_roles = merge(
    {
      plan = [for e in local.envs : { scope = "folder", key = e, role = local.custom_role_ids["redis_auth_reader"] }]
      "2-security" = [
        { scope = "org", key = "org", role = "roles/accesscontextmanager.policyAdmin" },
        { scope = "project", key = "security", role = "roles/cloudkms.admin" },
        { scope = "project", key = "security", role = "roles/secretmanager.admin" },
        { scope = "project", key = "security", role = "roles/serviceusage.serviceUsageAdmin" },
        # Attestor qa-approved y su nota de Container Analysis (ADR 0022-k).
        { scope = "project", key = "security", role = "roles/binaryauthorization.attestorsAdmin" },
        { scope = "project", key = "security", role = "roles/containeranalysis.notes.editor" },
      ]
      # Firma las imágenes de prod que QA aprobó (ADR 0022-k). signerVerifier sobre la llave y attestorsVerifier sobre el
      # attestor los da 2-security sobre esos recursos. El proyecto de seguridad solo guarda la nota qa-approved y sus
      # atestaciones.
      "attestor-prod" = [
        { scope = "project", key = "security", role = "roles/containeranalysis.notes.attacher" },
        { scope = "project", key = "security", role = "roles/containeranalysis.occurrences.editor" },
        # attest-images.sh lista las atestaciones existentes antes de firmar (notes.listOccurrences).
        { scope = "project", key = "security", role = "roles/containeranalysis.notes.occurrences.viewer" },
      ]
      "3-networks-hub" = [
        { scope = "project", key = "net_hub", role = "roles/compute.networkAdmin" },
        { scope = "project", key = "net_hub", role = "roles/compute.securityAdmin" },
        { scope = "project", key = "net_hub", role = "roles/dns.admin" },
        { scope = "project", key = "net_hub", role = "roles/serviceusage.serviceUsageAdmin" },
        { scope = "project", key = "net_hub", role = "roles/networkconnectivity.hubAdmin" },
        # VM servidor de onprem-sim (ADR 0005-e), sin cuenta de servicio.
        { scope = "project", key = "net_hub", role = "roles/compute.instanceAdmin.v1" },
      ]
    },
    {
      for e in local.envs : "3-networks-${e}" => [
        { scope = "folder", key = e, role = "roles/compute.xpnAdmin" },
        { scope = "project", key = "net-host-${e}", role = "roles/compute.networkAdmin" },
        { scope = "project", key = "net-host-${e}", role = "roles/compute.securityAdmin" },
        { scope = "project", key = "net-host-${e}", role = "roles/dns.admin" },
        { scope = "project", key = "net-host-${e}", role = "roles/servicenetworking.networksAdmin" },
        { scope = "project", key = "net-host-${e}", role = "roles/serviceusage.serviceUsageAdmin" },
        { scope = "project", key = "net_hub", role = "roles/dns.peer" },
        { scope = "project", key = "net-host-${e}", role = "roles/networkconnectivity.spokeAdmin" },
        # Unir el spoke al grupo edge del hub (networkconnectivity.groups.use).
        { scope = "project", key = "net_hub", role = "roles/networkconnectivity.groupUser" },
        # Llaves y valores de tag seguros (purpose GCE_FIREWALL) que usan las reglas del firewall del entorno.
        { scope = "project", key = "net-host-${e}", role = "roles/resourcemanager.tagAdmin" },
      ]
    },
    {
      for e in local.envs : "4-projects-${e}" => concat([
        { scope = "folder", key = e, role = "roles/resourcemanager.projectCreator" },
        { scope = "folder", key = e, role = "roles/resourcemanager.projectIamAdmin" },
        { scope = "folder", key = e, role = "roles/serviceusage.serviceUsageAdmin" },
        { scope = "folder", key = e, role = "roles/iam.serviceAccountAdmin" },
        # xpnAdmin incluye compute.subnetworks.setIamPolicy: cubre el adjunto a Shared VPC y el IAM de subredes del host.
        { scope = "folder", key = e, role = "roles/compute.xpnAdmin" },
        # El IAM de las llaves (rol a medida kms_key_iam_admin) lo concede 2-security por keyring del entorno.
        # tagUser sobre los valores de tag del net-host, para las identidades que vinculan tags.
        { scope = "project", key = "net-host-${e}", role = local.custom_role_ids["tag_value_iam_admin"] },
        ],
        # La política de acceso guarda los tres perímetros y su IAM no baja a cada perímetro: solo la SA de prod,
        # con aprobación, la edita. Los proyectos de dev y qa los agrega 2-security (ADR 0007-f).
        e == "prod" ? [{ scope = "org", key = "org", role = "roles/accesscontextmanager.policyEditor" }] : [],
        # Política de Binary Authorization del proyecto de app: solo prod exige la atestación qa-approved (ADR 0022-k).
        e == "prod" ? [{ scope = "folder", key = e, role = "roles/binaryauthorization.policyEditor" }] : [],
      )
    },
    {
      for e in local.envs : "5-workloads-${e}" => [
        { scope = "folder", key = e, role = "roles/container.admin" },
        { scope = "folder", key = e, role = "roles/compute.instanceAdmin.v1" },
        { scope = "folder", key = e, role = "roles/cloudsql.admin" },
        { scope = "folder", key = e, role = "roles/storage.admin" },
        { scope = "folder", key = e, role = "roles/compute.networkUser" },
        { scope = "folder", key = e, role = "roles/monitoring.editor" },
        # Cloud Run, Memorystore y Backup and DR (ADR 0023); securityAdmin crea la política de Cloud Armor
        # (loadBalancerAdmin, que da 4-projects, solo la usa).
        { scope = "folder", key = e, role = "roles/run.admin" },
        { scope = "folder", key = e, role = "roles/redis.admin" },
        { scope = "folder", key = e, role = "roles/backupdr.admin" },
        { scope = "folder", key = e, role = "roles/compute.securityAdmin" },
        # 5-workloads busca por nombre la tag key de firewall en el net-host (ADR 0019-i).
        { scope = "project", key = "net-host-${e}", role = "roles/resourcemanager.tagViewer" },
        # Agregar net_hub al metrics scope del proyecto de app exige monitoring.metricsScopes.link también en net_hub;
        # monitoring.viewer/editor no lo incluyen y metricsScopesAdmin es el rol predefinido más chico que sí.
        { scope = "project", key = "net_hub", role = "roles/monitoring.metricsScopesAdmin" },
      ]
    },
  )

  stage_sa_bindings = {
    for b in flatten([
      for sa, roles in local.stage_sa_roles : [
        for r in roles : {
          id     = "${sa}|${r.scope}|${r.key}|${r.role}"
          member = "serviceAccount:${local.stage_sas[sa]}"
          scope  = r.scope
          key    = r.key
          role   = r.role
        }
      ]
    ]) : b.id => b
  }

  iam_bindings = merge(local.group_bindings, local.stage_sa_bindings)
}

resource "google_organization_iam_custom_role" "this" {
  for_each = local.custom_roles

  org_id      = var.org_id
  role_id     = each.key
  title       = each.value.title
  permissions = each.value.permissions
  stage       = "GA"
}

resource "google_organization_iam_member" "this" {
  for_each = { for k, b in local.iam_bindings : k => b if b.scope == "org" }

  org_id = var.org_id
  role   = each.value.role
  member = each.value.member
}

resource "google_folder_iam_member" "this" {
  for_each = { for k, b in local.iam_bindings : k => b if b.scope == "folder" }

  folder = google_folder.this[each.value.key].name
  role   = each.value.role
  member = each.value.member

  depends_on = [google_organization_iam_custom_role.this]
}

resource "google_project_iam_member" "this" {
  for_each = { for k, b in local.iam_bindings : k => b if b.scope == "project" }

  project = local.project_ids[each.value.key]
  role    = each.value.role
  member  = each.value.member

  depends_on = [google_organization_iam_custom_role.this]
}

resource "google_storage_bucket_iam_member" "audit_readers" {
  for_each = { for k, b in local.iam_bindings : k => b if b.scope == "audit_bucket" }

  bucket = google_storage_bucket.audit.name
  role   = each.value.role
  member = each.value.member
}

# 5-workloads da roles/backupdr.cloudSqlOperator a la cuenta de la bóveda de Backup and DR, que solo existe al crearla:
# projectIamAdmin limitado por condición a ese único rol (ADR 0023).
resource "google_folder_iam_member" "workloads_backupdr_grant" {
  for_each = toset(local.envs)

  folder = google_folder.this[each.key].name
  role   = "roles/resourcemanager.projectIamAdmin"
  member = "serviceAccount:${local.stage_sas["5-workloads-${each.key}"]}"

  condition {
    title       = "solo-backupdr-cloudsql"
    description = "Solo puede otorgar o quitar roles/backupdr.cloudSqlOperator"
    expression  = "api.getAttribute('iam.googleapis.com/modifiedGrantsByRole', []).hasOnly(['roles/backupdr.cloudSqlOperator'])"
  }
}
