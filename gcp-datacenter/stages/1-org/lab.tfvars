# Ajustes de la organización de prueba (sin secretos). El pipeline lo pasa con -var-file (pesa más que TF_VAR_*); a mano: -var-file=lab.tfvars.
# Cuenta de facturación con cuota de 5 proyectos: un proyecto common y uno por entorno.
compact_projects = true
# Organización desechable: no bloquear la retención del bucket de auditoría (true es irreversible).
audit_retention_locked = false
