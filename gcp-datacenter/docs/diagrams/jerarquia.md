# Jerarquía de recursos

```mermaid
flowchart TD
  org["Organización"]
  org --> fb["Carpeta bootstrap"]
  org --> fc["Carpeta common"]
  org --> fd["Carpeta dev"]
  org --> fq["Carpeta qa"]
  org --> fp["Carpeta prod"]

  fb --> seed["acme-bootstrap-seed-xxxx<br/>bucket de estado (CMEK), WIF, SA de etapas"]

  fc --> nethub["acme-common-net-hub-xxxx<br/>VPC hub, HA VPN, NCC"]
  fc --> logging["acme-common-logging-xxxx<br/>sink de auditoría"]
  fc --> security["acme-common-security-xxxx<br/>KMS, Secret Manager"]
  fc --> backup["acme-common-backup-xxxx"]

  fd --> dhost["acme-dev-net-host-xxxx<br/>Shared VPC host"]
  fd --> dapp["acme-dev-app-xxxx"]
  fd --> ddata["acme-dev-data-xxxx"]

  fq --> qhost["acme-qa-net-host-xxxx"]
  fq --> qapp["acme-qa-app-xxxx"]
  fq --> qdata["acme-qa-data-xxxx"]

  fp --> phost["acme-prod-net-host-xxxx"]
  fp --> papp["acme-prod-app-xxxx"]
  fp --> pdata["acme-prod-data-xxxx"]

  dhost -. "Shared VPC" .-> dapp
  dhost -. "Shared VPC" .-> ddata
  qhost -. "Shared VPC" .-> qapp
  qhost -. "Shared VPC" .-> qdata
  phost -. "Shared VPC" .-> papp
  phost -. "Shared VPC" .-> pdata
```

- `xxxx` es `var.suffix` (4 caracteres hex) para que los IDs globales sean únicos.
- Las org policies y el firewall jerárquico se aplican en la organización (`1-org`).
- Cada entorno tiene su perímetro de VPC Service Controls (`2-security`, en dry-run: ADR 0006-e).
- Etapa responsable: carpetas y proyectos comunes en `1-org`; hosts de red en `1-org` y su red en
  `3-networks`; proyectos de app y datos en `4-projects`.
