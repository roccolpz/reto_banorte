# ADR 0016-j: GitHub Actions como herramienta de CI/CD

- Estado: aceptada
- Fecha: 2026-11-23

## Contexto

La especificación pide un pipeline que valide, genere el plan, pida aprobación y aplique sin llaves estáticas, con
dos aprobaciones en prod y sin cambios manuales en producción. El código vive en GitHub.

## Decisión

GitHub Actions ejecuta todo el ciclo:

- `ci.yml` en cada PR: formato, tflint, validate, `terraform test`, Checkov, pruebas de políticas, plan y la compilación
  de Terratest.
- `apply.yml` al fusionar a main: dev, pruebas de humo de dev, qa, y prod con dos aprobaciones.
- `drift.yml` diario y `terratest.yml` nocturno.

Se autentica con Workload Identity Federation (ADR 0004-e) y suplanta una SA por etapa y entorno. Los environments
de GitHub (`dev`, `qa`, `prod`) dan las aprobaciones, y WIF limita las SA de prod al environment `prod`.

## Alternativas descartadas

- **Cloud Build**: también tiene aprobaciones y no necesita WIF, pero las revisiones de PR, los checks y las
  aprobaciones quedarían repartidos entre GitHub y la consola de GCP. Además, el pipeline tendría que vivir dentro
  de la organización que despliega.
- **HCP Terraform / Terraform Cloud**: guarda el estado fuera de GCP, cuando ADR 0003-e lo deja en GCS con CMEK, y
  el plan gratuito limita usuarios y ejecuciones concurrentes.
- **Atlantis**: hay que operar y asegurar un servidor con permisos sobre toda la organización.
- **GitLab CI**: exige mover el repositorio.

## Consecuencias

- La protección de main y los environments se configuran en GitHub; no hay Terraform para ellos en esta entrega.
- Las acciones de terceros se fijan por SHA para que una etiqueta movida no cambie el pipeline.
- Los minutos de Actions del plan de la organización limitan la frecuencia de Terratest.
