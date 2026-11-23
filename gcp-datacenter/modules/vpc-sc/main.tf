locals {
  # Configuración única para status (aplicado) o spec (dry-run). HCL no permite compartir el cuerpo de un bloque,
  # así que las reglas se arman aquí como datos y cada bloque dinámico solo las copia.
  config = {
    restricted_services = var.restricted_services
    resources           = [for p in var.member_projects : "projects/${p}"]
    ingress             = length(var.ingress_identities) > 0 ? [{ identities = var.ingress_identities }] : []
    egress              = var.egress_rules
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
        for_each = status.value.ingress
        content {
          ingress_from {
            identities = ingress_policies.value.identities
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
        for_each = status.value.egress
        content {
          egress_from {
            identities = egress_policies.value.identities
          }
          egress_to {
            resources = egress_policies.value.resources
            dynamic "operations" {
              for_each = egress_policies.value.services
              content {
                service_name = operations.value
                method_selectors {
                  method = "*"
                }
              }
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
        for_each = spec.value.ingress
        content {
          ingress_from {
            identities = ingress_policies.value.identities
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
        for_each = spec.value.egress
        content {
          egress_from {
            identities = egress_policies.value.identities
          }
          egress_to {
            resources = egress_policies.value.resources
            dynamic "operations" {
              for_each = egress_policies.value.services
              content {
                service_name = operations.value
                method_selectors {
                  method = "*"
                }
              }
            }
          }
        }
      }
    }
  }

  # Los proyectos de app y datos se agregan con recursos *_perimeter_resource / *_dry_run_resource.
  lifecycle {
    ignore_changes = [status[0].resources, spec[0].resources]
  }
}
