# Runbook: destruir el entorno dev

Cuándo: para ahorrar costo, o para demostrar el criterio de aceptación "destroy de dev". Solo dev. Nunca qa ni prod.

Qué no se borra: las llaves KMS (GCP no las borra; quedan programadas para destrucción) y los proyectos borrados quedan
30 días en estado `DELETE_REQUESTED`. Por eso los nombres llevan `suffix`.

## Requisitos

- `deletion_protection = false` en dev (default del contrato §8).
- Permiso para impersonar las SA de dev, o una cuenta de administrador.
- Nadie aplicando dev al mismo tiempo: pausa el workflow `apply` o asegúrate de que no haya merges pendientes.

## Pasos

En orden inverso a la creación, en cada raíz:

```bash
export TF_STATE_BUCKET=<bucket>
export TF_VAR_state_bucket=$TF_STATE_BUCKET
cd gcp-datacenter/stages/5-workloads/envs/dev
terraform init -backend-config="bucket=$TF_STATE_BUCKET"
terraform plan -destroy -out=destroy.tfplan
# revisa que solo aparezcan recursos de dev
terraform apply destroy.tfplan
```

Repite en:

1. `5-workloads/envs/dev`
2. `4-projects/envs/dev`
3. `3-networks/envs/dev`

No destruyas `3-networks/hub`, `2-security` ni `1-org`: qa y prod dependen de ellos.

## Comprobar

- `terraform plan` en cada raíz destruida dice que crearía todo (estado vacío).
- `gcloud projects list --filter 'labels.env=dev'` no muestra proyectos activos.

## Volver a crear

Ejecuta el workflow `apply` con "Run workflow", o aplica las tres raíces en orden normal (3 → 4 → 5).

## Si falla

- **Recurso con protección de borrado**: revisa que el entorno sea dev y que la variable esté en `false`; aplícalo
  primero y luego destruye.
- **Subred en uso por un recurso fuera de Terraform**: bórralo a mano o impórtalo y vuelve a intentar.
- **Perímetro de VPC-SC bloquea la operación** (solo si está aplicado): revisa los registros de auditoría y la regla
  de ingreso de la SA (ADR 0006-e).
