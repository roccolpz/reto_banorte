# Flujo de CI/CD

```mermaid
flowchart TD
  pr["Pull request a main"] --> detect["detect: raíces y módulos afectados<br/>(scripts/discover-roots.sh)"]
  detect --> fmt["terraform fmt -check"]
  detect --> tflint["tflint + ruleset google"]
  detect --> checkov["checkov (sin soft-fail)"]
  detect --> ptest["conftest verify<br/>+ planes de ejemplo"]
  detect --> mtest["terraform test por módulo"]
  detect --> validate["init -backend=false + validate<br/>por raíz"]
  validate --> plan
  ptest --> plan
  plan["plan por raíz (SA plan vía WIF)<br/>show -json + conftest test"] --> comment["Comentario en el PR<br/>resumen del plan y políticas"]
  comment --> review["Revisión de CODEOWNERS<br/>y checks en verde"]
  review --> merge["Merge a main"]

  merge --> cgate{"environment prod<br/>2 aprobaciones"}
  cgate --> common["Comunes<br/>1-org → 2-security → 3-networks/hub"]
  common --> devc["dev (automático)<br/>3-networks → 4-projects → 5-workloads"]
  devc --> qac["qa (automático)<br/>3-networks → 4-projects → 5-workloads"]
  qac --> gate{"environment prod<br/>2 aprobaciones"}
  gate --> prodc["prod<br/>3-networks → 4-projects → 5-workloads"]

  cron["Cron diario 12:00 UTC"] --> drift["plan -detailed-exitcode por raíz"]
  drift -->|"código 2"| issue["Issue 'Drift: raíz'<br/>etiqueta drift"]
  drift -->|"código 0"| close["Cierra el issue abierto"]
```

- Solo se aplican las raíces que cambió el push; un cambio en `modules/` aplica todas.
- Cada raíz aplica con la SA de su etapa y entorno; los jobs de una misma raíz no corren en paralelo.
- `0-bootstrap` no está en el pipeline: lo aplica un administrador (runbook `bootstrap-first-apply.md`).
