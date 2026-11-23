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
  description = "env → accessPolicies/<n>/servicePerimeters/<nombre>. 4-projects agrega los proyectos de app y datos."
  value       = { for env, m in module.perimeter : env => m.name }
}
