# Ajustes de la organización de prueba (sin secretos). El pipeline lo pasa con -var-file (pesa más que TF_VAR_*); a mano: -var-file=lab.tfvars.
# Todo el DR queda (réplica de Cloud SQL, clúster GKE DR, bucket dual-region, VPN en us-east4), pero:
# - regional = false: la cuota de 12 vCPU por proyecto no alcanza dos clústeres regionales.
# - deletion_protection = false: para poder destruir prod y cuidar créditos.
regional            = false
deletion_protection = false
