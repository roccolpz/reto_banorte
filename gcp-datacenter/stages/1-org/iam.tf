# IAM de grupos humanos (Fase 3, §3.2) y de las SAs de las etapas 2 a 5.
# Cada binding se identifica como "<principal>|<tipo de alcance>|<llave del alcance>|<rol>".
# Tipos de alcance: org, folder (common/dev/qa/prod), project (llave de local.project_ids),
# y audit_bucket. El rol billing.admin del grupo billing_admins se otorga a mano en la cuenta de
# facturación: la SA de 1-org solo tiene billing.user, sin billing.accounts.setIamPolicy.

locals {
  stage_sas = data.terraform_remote_state.bootstrap.outputs.stage_service_accounts

  project_ids = merge(
    { for k, p in module.common_project : k => p.project_id },
    { for e, p in module.net_host_project : "net-host-${e}" => p.project_id },
  )

  # Roles por grupo. Solo se aplican los grupos presentes en var.groups.
  group_roles = {
    org_admins = [
      { scope = "org", key = "org", role = "roles/resourcemanager.organizationAdmin" },
      { scope = "org", key = "org", role = "roles/resourcemanager.folderAdmin" },
      { scope = "org", key = "org", role = "roles/orgpolicy.policyAdmin" },
    ]
    billing_admins = [
      { scope = "org", key = "org", role = "roles/billing.viewer" },
    ]
    security_admins = [
      { scope = "org", key = "org", role = "roles/iam.securityReviewer" },
      { scope = "org", key = "org", role = "roles/securitycenter.admin" },
      { scope = "org", key = "org", role = "roles/orgpolicy.policyViewer" },
      { scope = "project", key = "security", role = "roles/cloudkms.admin" },
    ]
    network_admins = [
      { scope = "org", key = "org", role = "roles/compute.networkViewer" },
      { scope = "project", key = "net_hub", role = "roles/compute.networkAdmin" },
      { scope = "project", key = "net-host-dev", role = "roles/compute.networkAdmin" },
      { scope = "project", key = "net-host-qa", role = "roles/compute.networkAdmin" },
      { scope = "project", key = "net-host-prod", role = "roles/compute.networkAdmin" },
    ]
    devops = [
      { scope = "folder", key = "dev", role = "roles/container.admin" },
      { scope = "folder", key = "qa", role = "roles/container.admin" },
      { scope = "folder", key = "dev", role = "roles/compute.instanceAdmin.v1" },
      { scope = "folder", key = "qa", role = "roles/compute.instanceAdmin.v1" },
      { scope = "folder", key = "prod", role = "roles/viewer" },
    ]
    developers = [
      { scope = "folder", key = "dev", role = "roles/container.developer" },
      { scope = "folder", key = "dev", role = "roles/viewer" },
      { scope = "folder", key = "qa", role = "roles/viewer" },
    ]
    auditors = [
      { scope = "org", key = "org", role = "roles/iam.securityReviewer" },
      { scope = "org", key = "org", role = "roles/logging.privateLogViewer" },
      { scope = "org", key = "org", role = "roles/browser" },
      { scope = "audit_bucket", key = "audit", role = "roles/storage.objectViewer" },
    ]
  }

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
      "2-security" = [
        { scope = "org", key = "org", role = "roles/accesscontextmanager.policyAdmin" },
        { scope = "project", key = "security", role = "roles/cloudkms.admin" },
        { scope = "project", key = "security", role = "roles/secretmanager.admin" },
        { scope = "project", key = "security", role = "roles/serviceusage.serviceUsageAdmin" },
      ]
      "3-networks-hub" = [
        { scope = "project", key = "net_hub", role = "roles/compute.networkAdmin" },
        { scope = "project", key = "net_hub", role = "roles/compute.securityAdmin" },
        { scope = "project", key = "net_hub", role = "roles/dns.admin" },
        { scope = "project", key = "net_hub", role = "roles/serviceusage.serviceUsageAdmin" },
        { scope = "project", key = "net_hub", role = "roles/networkconnectivity.hubAdmin" },
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
        # cloudkms.admin sobre las llaves lo concede 2-security por keyring del entorno, no aquí sobre todo el proyecto.
        ],
        # La política de acceso guarda los tres perímetros y su IAM no baja a cada perímetro: solo la SA de prod,
        # con aprobación, la edita. Los proyectos de dev y qa los agrega 2-security (ADR 0007-f).
        e == "prod" ? [{ scope = "org", key = "org", role = "roles/accesscontextmanager.policyEditor" }] : [],
      )
    },
    {
      for e in local.envs : "5-workloads-${e}" => [
        { scope = "folder", key = e, role = "roles/container.admin" },
        { scope = "folder", key = e, role = "roles/compute.instanceAdmin.v1" },
        { scope = "folder", key = e, role = "roles/cloudsql.admin" },
        { scope = "folder", key = e, role = "roles/storage.admin" },
        { scope = "folder", key = e, role = "roles/iam.serviceAccountUser" },
        { scope = "folder", key = e, role = "roles/compute.networkUser" },
        { scope = "folder", key = e, role = "roles/monitoring.editor" },
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
}

resource "google_project_iam_member" "this" {
  for_each = { for k, b in local.iam_bindings : k => b if b.scope == "project" }

  project = local.project_ids[each.value.key]
  role    = each.value.role
  member  = each.value.member
}

resource "google_storage_bucket_iam_member" "audit_readers" {
  for_each = { for k, b in local.iam_bindings : k => b if b.scope == "audit_bucket" }

  bucket = google_storage_bucket.audit.name
  role   = each.value.role
  member = each.value.member
}
