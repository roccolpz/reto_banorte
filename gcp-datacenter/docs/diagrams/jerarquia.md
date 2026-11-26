# Jerarquía de recursos

Lo desplegado en la organización de prueba usa `compact_projects = true` (`stages/1-org/lab.tfvars`): un proyecto
`common` y un proyecto por entorno que aloja red, app y datos. Así cabe en la cuota de proyectos y créditos.

```mermaid
flowchart TD
  org["Organización 544577283167<br/>org policies + firewall jerárquico (1-org)"]
  org --> fb["Carpeta bootstrap"]
  org --> fc["Carpeta common"]
  org --> fd["Carpeta dev"]
  org --> fq["Carpeta qa"]
  org --> fp["Carpeta prod"]

  fb --> seed["acme-bootstrap-seed-346e<br/>bucket de estado (CMEK), WIF, SA por etapa"]
  fc --> common["acme-common-346e<br/>VPC hub, HA VPN, NCC, DNS · KMS, Secret Manager<br/>sink de auditoría · attestor de Binary Authorization<br/>on-prem simulado (VPC aparte)"]
  fd --> dev["acme-dev-346e<br/>VPC dev + GKE, MIG, Cloud SQL, Redis, Cloud Run"]
  fq --> qa["acme-qa-346e<br/>VPC qa + mismas cargas"]
  fp --> prod["acme-prod-346e<br/>VPC prod (us-central1 + us-east4)<br/>cargas + DR, balanceador con Cloud Armor, Backup and DR"]

  common -. "NCC spoke" .- dev
  common -. "NCC spoke" .- qa
  common -. "NCC spoke" .- prod
```

- Cada entorno tiene su perímetro de VPC Service Controls (`2-security`, en dry-run: ADR 0006-e).
- Con `compact_projects = false` el diseño completo separa cada carpeta en proyectos por función: `common` en
  `net-hub`, `logging`, `security` y `backup`; cada entorno en `net-host` (Shared VPC), `app` y `data`. El código es
  el mismo; solo cambia la variable.
- `346e` es `var.suffix` (4 caracteres hex) para que los IDs globales sean únicos.
- Etapa responsable: carpetas y proyectos en `1-org`; red en `3-networks`; proyectos de entorno en `4-projects`;
  cargas en `5-workloads`.
