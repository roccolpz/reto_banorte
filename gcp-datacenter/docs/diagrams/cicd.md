# Flujo de CI/CD

```mermaid
flowchart TD
  pr["Pull request a main"] --> detect["detect: raíces y módulos afectados<br/>(scripts/discover-roots.sh)"]
  detect --> fmt["terraform fmt -check"]
  detect --> tflint["tflint + ruleset google"]
  detect --> checkov["checkov (sin soft-fail)"]
  detect --> ptest["conftest verify<br/>+ pruebas de scripts"]
  detect --> mtest["terraform test por módulo<br/>+ compilación de Terratest"]
  detect --> validate["init -backend=false + validate<br/>por raíz"]
  validate --> plan
  ptest --> plan
  plan["plan por raíz (SA plan vía WIF)<br/>conftest sobre plan.json + Infracost"] --> comment["Comentario en el PR<br/>plan, políticas y costo mensual"]
  fmt & tflint & checkov & mtest & comment --> ciok{"ci-ok<br/>check obligatorio"}
  ciok --> review["Ruleset main-protegida<br/>CODEOWNERS + aprobaciones de QA"]
  review --> merge["Merge a main"]

  merge --> qagate{"qa-approval<br/>2 aprobaciones de QA si toca<br/>prod, comunes o imágenes"}
  qagate --> common["Comunes (environment prod)<br/>1-org → 2-security → 3-networks/hub"]
  qagate --> attest["attest-prod (environment prod)<br/>firma release/prod-images.txt"]
  common --> devc["dev<br/>3-networks → 4-projects → 5-workloads"]
  devc --> tests["tests-dev<br/>pruebas de humo en dev"]
  tests --> qac["qa<br/>3-networks → 4-projects → 5-workloads"]
  qac --> gate{"environment prod<br/>aprobación manual"}
  gate --> prodc["prod<br/>3-networks → 4-projects → 5-workloads"]

  cron["Cron diario 12:00 UTC"] --> drift["drift: plan -detailed-exitcode<br/>en las 13 raíces"]
  drift -->|"código 2"| issue["Issue 'Drift: raíz'<br/>etiqueta drift"]
  drift -->|"código 0"| close["Cierra el issue abierto"]

  cron2["Cron diario 06:00 UTC"] --> terratest["terratest: apply, plan sin cambios<br/>y destroy por módulo en proyecto efímero"]
```

- Solo se aplican las raíces que cambió el push; un cambio en `modules/` aplica todas.
- Cada raíz aplica con la SA de su etapa y entorno; los jobs de una misma raíz no corren en paralelo.
- La puerta de QA está relajada temporalmente con `QA_MIN_APPROVALS` (ADR 0021-k); se restaura antes de la entrega.
- Infracost necesita el secreto `INFRACOST_API_KEY`; sin él el paso se omite y el PR no se bloquea.
- `0-bootstrap` no está en el pipeline: lo aplica un administrador (runbook `bootstrap-first-apply.md`).
