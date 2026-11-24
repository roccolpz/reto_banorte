# Políticas de organización (API v2), heredadas por todo el árbol.

locals {
  boolean_policies = [
    "iam.disableServiceAccountKeyCreation",
    "compute.requireShieldedVm",
    "storage.publicAccessPrevention",
    "sql.restrictPublicIp",
    "compute.skipDefaultNetworkCreation",
  ]

  list_deny_all_policies = [
    "compute.vmExternalIpAccess",
  ]
}

resource "google_org_policy_policy" "boolean" {
  for_each = toset(local.boolean_policies)

  name   = "${local.org}/policies/${each.key}"
  parent = local.org

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}

resource "google_org_policy_policy" "list_deny_all" {
  for_each = toset(local.list_deny_all_policies)

  name   = "${local.org}/policies/${each.key}"
  parent = local.org

  spec {
    rules {
      deny_all = "TRUE"
    }
  }
}

resource "google_org_policy_policy" "resource_locations" {
  name   = "${local.org}/policies/gcp.resourceLocations"
  parent = local.org

  spec {
    rules {
      values {
        # us: código del bucket dual-region y del keyring de su llave CMEK (ADR 0002-d); no abre todo in:us-locations.
        allowed_values = ["in:us-central1-locations", "in:us-east4-locations", "us"]
      }
    }
  }
}

# Solo si se conocen los IDs de cliente; sin ellos la política bloquearía a todos los miembros.
resource "google_org_policy_policy" "allowed_domains" {
  count = length(var.allowed_policy_member_customer_ids) > 0 ? 1 : 0

  name   = "${local.org}/policies/iam.allowedPolicyMemberDomains"
  parent = local.org

  spec {
    rules {
      values {
        allowed_values = var.allowed_policy_member_customer_ids
      }
    }
  }
}
