locals {
  # Misma configuración para status (aplicado) o spec (dry-run); solo cambia el bloque que la recibe.
  config = {
    restricted_services = var.restricted_services
    resources           = [for p in var.member_projects : "projects/${p}"]
  }
}

resource "google_access_context_manager_service_perimeter" "perimeter" {
  parent                    = "accessPolicies/${var.access_policy_name}"
  name                      = "accessPolicies/${var.access_policy_name}/servicePerimeters/${var.perimeter_name}"
  title                     = var.perimeter_name
  perimeter_type            = "PERIMETER_TYPE_REGULAR"
  use_explicit_dry_run_spec = !var.enforce

  dynamic "status" {
    for_each = var.enforce ? [local.config] : []
    content {
      restricted_services = status.value.restricted_services
      resources           = status.value.resources

      dynamic "ingress_policies" {
        for_each = length(var.ingress_identities) > 0 ? [1] : []
        content {
          ingress_from {
            identities = var.ingress_identities
            sources {
              access_level = "*"
            }
          }
          ingress_to {
            resources = ["*"]
            operations {
              service_name = "*"
            }
          }
        }
      }

      dynamic "egress_policies" {
        for_each = length(var.egress_identities) > 0 ? [1] : []
        content {
          egress_from {
            identities = var.egress_identities
          }
          egress_to {
            resources = ["*"]
            operations {
              service_name = "*"
            }
          }
        }
      }
    }
  }

  dynamic "spec" {
    for_each = var.enforce ? [] : [local.config]
    content {
      restricted_services = spec.value.restricted_services
      resources           = spec.value.resources

      dynamic "ingress_policies" {
        for_each = length(var.ingress_identities) > 0 ? [1] : []
        content {
          ingress_from {
            identities = var.ingress_identities
            sources {
              access_level = "*"
            }
          }
          ingress_to {
            resources = ["*"]
            operations {
              service_name = "*"
            }
          }
        }
      }

      dynamic "egress_policies" {
        for_each = length(var.egress_identities) > 0 ? [1] : []
        content {
          egress_from {
            identities = var.egress_identities
          }
          egress_to {
            resources = ["*"]
            operations {
              service_name = "*"
            }
          }
        }
      }
    }
  }

  # Los proyectos de app y datos los agrega 4-projects con recursos *_perimeter_resource / *_dry_run_resource.
  lifecycle {
    ignore_changes = [status[0].resources, spec[0].resources]
  }
}
