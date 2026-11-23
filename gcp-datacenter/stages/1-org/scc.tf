# Notificaciones de Security Command Center (Fase 3 §3.3: "SCC identifica hallazgos").
# Activar SCC en la organización es un paso manual previo (ADR 0010-g); aquí solo se envían los hallazgos activos
# a un tópico del proyecto de seguridad. Al crear la notificación, SCC concede pubsub.publisher en el tópico a su
# agente de servicio, por eso la SA de 1-org necesita setIamPolicy en el tópico (la tiene como creadora del proyecto).

resource "google_pubsub_topic" "scc_findings" {
  project = module.common_project["security"].project_id
  name    = "${var.prefix}-scc-findings"
  labels  = merge(local.labels, { env = "common" })

  message_storage_policy {
    allowed_persistence_regions = [var.region]
  }
}

resource "google_pubsub_subscription" "scc_findings" {
  project = module.common_project["security"].project_id
  name    = "${var.prefix}-scc-findings"
  topic   = google_pubsub_topic.scc_findings.id
  labels  = merge(local.labels, { env = "common" })

  message_retention_duration = "604800s"
}

resource "google_scc_v2_organization_notification_config" "findings" {
  organization = var.org_id
  location     = "global"
  config_id    = "${var.prefix}-scc-findings"
  description  = "Hallazgos activos de la organización hacia el tópico de seguridad"
  pubsub_topic = google_pubsub_topic.scc_findings.id

  streaming_config {
    filter = "state = \"ACTIVE\""
  }
}
