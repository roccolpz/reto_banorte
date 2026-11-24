# Ajustes de la organización de prueba (sin secretos). El pipeline lo pasa con -var-file (pesa más que TF_VAR_*); a mano: -var-file=lab.tfvars.
# La política de Access Context Manager la creó esta etapa; org_id llega como TF_VAR_org_id.
create_access_policy = true
