# reto_banorte: landing zone de GCP con Terraform

Código de una landing zone híbrida en Google Cloud: organización con carpetas y políticas, seguridad (KMS, Secret
Manager, VPC Service Controls), red hub-and-spoke con Network Connectivity Center y HA VPN hacia on-premises, proyectos
por entorno con Shared VPC, y cargas de ejemplo (GKE privado, MIG, Cloud SQL con IP privada, Cloud Storage).
Todo se despliega desde GitHub Actions con Workload Identity Federation, sin llaves de cuenta de servicio.

Alcance de esta entrega: [ADR 0001](gcp-datacenter/docs/adr/0001-alcance-entrega.md).

## Estructura

```
.github/
├── workflows/        ci.yml (PR), apply.yml (merge a main), drift.yml (diario), _tf-apply.yml (reutilizable)
├── actions/          tf-init, setup-conftest
├── CODEOWNERS
└── pull_request_template.md
gcp-datacenter/
├── modules/          módulos reutilizables (README, ejemplo y terraform test cada uno)
├── stages/           raíces de Terraform, una por etapa y entorno
├── policies/         políticas rego (conftest) que se evalúan sobre el plan
├── tests/            capas de prueba y prueba e2e de conectividad
├── scripts/          discover-roots.sh, validate-all.sh
├── docs/             CONTRATO.md, guía de operación, ADR, runbooks, diagramas
├── .tflint.hcl
└── .checkov.yaml
```

## Etapas

| Etapa | Qué crea | Se aplica |
|-------|----------|-----------|
| `0-bootstrap` | Proyecto semilla, bucket de estado con CMEK, WIF y una SA por etapa | A mano, una vez, por un administrador |
| `1-org` | Carpetas, proyectos comunes, org policies, firewall jerárquico, sink de auditoría | CI |
| `2-security` | KMS, Secret Manager, perímetros de VPC-SC (dry-run) | CI |
| `3-networks/hub` | VPC hub, HA VPN y BGP hacia on-prem, NCC, DNS de reenvío | CI |
| `3-networks/envs/<env>` | VPC de entorno con Shared VPC, subredes, Cloud NAT, PSA, DNS privado | CI |
| `4-projects/envs/<env>` | Proyectos de aplicación y datos, SA de cargas | CI |
| `5-workloads/envs/<env>` | GKE, MIG, Cloud SQL, buckets | CI |

Orden de apply: 1 → 2 → 3-hub, y luego por entorno 3 → 4 → 5, primero dev, después qa y al final prod.
Cada raíz tiene su propio estado (`<etapa>[/<entorno>]`) en el bucket de bootstrap
([ADR 0003-e](gcp-datacenter/docs/adr/0003-e-etapas-y-backend-gcs.md)).

Entornos: `dev` y `qa` en us-central1; `prod` en us-central1 con DR en us-east4. On-premises se simula con una VPC
conectada por HA VPN ([ADR 0005-e](gcp-datacenter/docs/adr/0005-e-onprem-simulado-ha-vpn.md)).

## Primer despliegue

1. Un administrador aplica `0-bootstrap` con estado local y lo migra al bucket que crea.
2. Se cargan en GitHub las variables (proveedor WIF, bucket, correos de las SA) y los environments.
3. Se ejecuta el workflow `apply`, que despliega el resto en orden.

Paso a paso: [runbooks/bootstrap-first-apply.md](gcp-datacenter/docs/runbooks/bootstrap-first-apply.md).

## CI/CD

- **Pull request** (`ci.yml`): formato, `tflint`, `checkov`, pruebas de módulos y de políticas, `validate` y `plan`
  por raíz afectada. El plan se evalúa con las políticas de `policies/` y se publica como comentario.
  Un plan que viola una política bloquea el merge.
- **Merge a `main`** (`apply.yml`): aplica las raíces afectadas en orden. dev y qa se aplican solos; prod espera dos
  aprobaciones en el environment `prod`.
- **Diario** (`drift.yml`): `plan -detailed-exitcode` en cada raíz; si hay drift abre un issue.

Configuración de variables, environments y protección de rama: [guía de operación](gcp-datacenter/docs/README.md).

## Comprobar en local

Sin credenciales de GCP:

```bash
gcp-datacenter/scripts/validate-all.sh
```

Corre `terraform fmt -check`, `init -backend=false` + `validate` en cada raíz y ejemplo, y `terraform test` en cada
módulo. Requiere Terraform 1.17.2.

## Documentación

- [Contrato de etapas y convenciones](gcp-datacenter/docs/CONTRATO.md)
- [Guía de operación](gcp-datacenter/docs/README.md)
- [Pruebas](gcp-datacenter/tests/README.md)
- [Runbooks](gcp-datacenter/docs/runbooks/)
- [ADR](gcp-datacenter/docs/adr/)
- Diagramas: [arquitectura](gcp-datacenter/docs/diagrams/arquitectura.md),
  [jerarquía](gcp-datacenter/docs/diagrams/jerarquia.md), [CI/CD](gcp-datacenter/docs/diagrams/cicd.md)
