resource "google_cloud_run_v2_service" "this" {
  name     = var.name
  project  = var.project_id
  location = var.region
  labels   = var.labels

  # Solo el balanceador (y la red interna) llegan al servicio; nunca la URL run.app pública.
  ingress             = var.ingress
  deletion_protection = var.deletion_protection

  # Sin IAM de invocador: el control de acceso es el ingreso (balanceador + Cloud Armor). La org policy
  # iam.allowedPolicyMemberDomains impide dar roles/run.invoker a allUsers.
  invoker_iam_disabled = var.invoker_iam_disabled

  template {
    service_account = var.service_account_email
    labels          = var.labels

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    containers {
      image = var.image

      resources {
        limits = {
          cpu    = var.cpu
          memory = var.memory
        }
        cpu_idle = true
      }
    }
  }

  # La API llena un bloque scaling a nivel servicio (min 0, manual 0) que no está en la configuración: sin esto cada
  # plan propone quitarlo y la prueba de humo de dev (plan sin cambios) falla. El escalado real va en template.scaling.
  lifecycle {
    ignore_changes = [scaling]
  }
}
