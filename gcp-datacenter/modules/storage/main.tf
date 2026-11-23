resource "google_storage_bucket" "this" {
  name                        = var.name
  project                     = var.project_id
  location                    = var.location
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = var.force_destroy
  labels                      = var.labels
  # rpo solo aplica a buckets dual-region.
  rpo = length(var.dual_region) == 2 ? (var.turbo_replication ? "ASYNC_TURBO" : "DEFAULT") : null

  dynamic "custom_placement_config" {
    for_each = length(var.dual_region) == 2 ? [1] : []
    content {
      data_locations = var.dual_region
    }
  }

  encryption {
    default_kms_key_name = var.kms_key_name
  }

  versioning {
    enabled = var.versioning
  }

  dynamic "lifecycle_rule" {
    for_each = var.lifecycle_rules
    content {
      action {
        type          = lifecycle_rule.value.action
        storage_class = lifecycle_rule.value.storage_class
      }
      condition {
        age                = lifecycle_rule.value.age
        num_newer_versions = lifecycle_rule.value.num_newer_versions
        with_state         = lifecycle_rule.value.with_state
      }
    }
  }
}
