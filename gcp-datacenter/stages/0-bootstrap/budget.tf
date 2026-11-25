# Presupuesto mensual de la cuenta de facturación con alertas por correo a los administradores de facturación
# (Riesgos: costos). La API de presupuestos exige un proyecto de cuota: se factura a la semilla.
provider "google" {
  alias                 = "billing"
  region                = var.region
  billing_project       = module.seed_project.project_id
  user_project_override = true
}

resource "google_billing_budget" "monthly" {
  provider = google.billing

  billing_account = var.billing_account
  display_name    = "${var.prefix} presupuesto mensual"

  budget_filter {
    calendar_period = "MONTH"
    # Los créditos de prueba cubren el gasto: el presupuesto mide el costo bruto para que la alerta sea útil.
    credit_types_treatment = "EXCLUDE_ALL_CREDITS"
  }

  amount {
    specified_amount {
      currency_code = var.budget_currency
      units         = tostring(var.budget_amount)
    }
  }

  dynamic "threshold_rules" {
    for_each = var.budget_thresholds
    content {
      threshold_percent = threshold_rules.value
    }
  }

  # Pronóstico: avisa antes de llegar al 100 %.
  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "FORECASTED_SPEND"
  }

  depends_on = [module.seed_project]
}
