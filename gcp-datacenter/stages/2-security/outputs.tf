output "kms_keys" {
  description = "[env][propósito] → ID de la llave. Propósitos: storage, sql, gke (us-central1); prod además sql-dr (us-east4) y storage-us (us)."
  value = {
    for env in local.envs : env => merge([
      for kr, cfg in local.keyrings : module.kms[kr].key_ids if cfg.env == env
    ]...)
  }
}

output "secret_ids" {
  description = "[env][nombre] → ID del secreto (contenedor sin versión)."
  value = {
    for env in local.envs : env => {
      for name in var.secret_names : name => google_secret_manager_secret.secrets["${env}/${name}"].id
    }
  }
}

output "access_policy_name" {
  description = "Número de la política de Access Context Manager."
  value       = local.access_policy_name
}

output "perimeter_names" {
  description = "env → accessPolicies/<n>/servicePerimeters/<nombre>. Los proyectos de app y datos los agrega 4-projects-prod (prod) o esta etapa (dev, qa; ADR 0007-f)."
  value       = { for env, m in module.perimeter : env => m.name }
}

output "vpc_sc_enforce" {
  description = "env → true si el perímetro está aplicado, false si está en dry-run. 4-projects lo lee para agregar sus proyectos con el recurso correcto."
  value       = var.vpc_sc_enforce
}
