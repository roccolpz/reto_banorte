variable "perimeter_name" { type = string }
variable "access_policy_name" { type = string }
variable "restricted_services" { type = list(string) }
variable "member_projects" { type = list(string) }

resource "google_access_context_manager_service_perimeter" "perimeter" {
  parent         = "accessPolicies/${var.access_policy_name}"
  name           = "accessPolicies/${var.access_policy_name}/servicePerimeters/${var.perimeter_name}"
  title          = var.perimeter_name
  perimeter_type = "PERIMETER_TYPE_REGULAR"

  status {
    restricted_services = var.restricted_services
    resources           = [for p in var.member_projects : "projects/${p}"]
  }
}