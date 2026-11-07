variable "policy_name" { type = string }
variable "perimeter_name" { type = string }
variable "parent_org_id" { type = string }
variable "restricted_services" { type = list(string) }
variable "member_projects" { type = list(string) } # Lista de números de proyecto (project numbers)

resource "google_access_context_manager_access_policy" "policy" {
  parent = "organizations/${var.parent_org_id}"
  title  = var.policy_name
}

resource "google_access_context_manager_service_perimeter" "perimeter" {
  parent         = "accessPolicies/${google_access_context_manager_access_policy.policy.name}"
  name           = "accessPolicies/${google_access_context_manager_access_policy.policy.name}/servicePerimeters/${var.perimeter_name}"
  title          = var.perimeter_name
  perimeter_type = "PERIMETER_TYPE_REGULAR"

  status {
    restricted_services = var.restricted_services
    resources           = [for p in var.member_projects : "projects/${p}"]
  }
}