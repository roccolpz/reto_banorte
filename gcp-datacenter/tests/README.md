# Pruebas

Las pruebas van de la más barata a la más cara. Las tres primeras capas corren en cada pull request sin tocar GCP;
la cuarta necesita credenciales y la quinta necesita la infraestructura aplicada.

| Capa | Qué prueba | Dónde vive | Cómo se corre |
|------|------------|------------|---------------|
| 1. Estáticas | Formato, sintaxis, buenas prácticas y seguridad del código | todo `gcp-datacenter/` | `terraform fmt -check`, `terraform validate`, `tflint` (`.tflint.hcl`), `checkov` (`.checkov.yaml`) |
| 2. Módulos y raíces | Lógica de cada módulo y raíz con proveedores simulados (`mock_provider`) | `modules/<módulo>/tests/`, `stages/<raíz>/tests/` | `terraform -chdir=<dir> test` |
| 3. Políticas | Reglas de cumplimiento sobre el plan en JSON | `policies/*.rego`, pruebas en `policies/*_test.rego`, planes de ejemplo en `policies/testdata/` | `conftest verify --policy policies` |
| 4. Plan | El plan real de cada raíz afectada cumple las políticas | CI, job `plan` | `terraform show -json tfplan` y `conftest test` |
| 5. E2E | Conectividad híbrida real después del apply | `tests/e2e/connectivity.sh` | a mano, después del apply de prod |

## Local

`scripts/validate-all.sh` corre las capas 1 (fmt y validate) y 2 sin credenciales ni backend:

```bash
gcp-datacenter/scripts/validate-all.sh
```

tflint, checkov y conftest corren en CI con versiones fijadas; instalarlos en local es opcional.

## Políticas

Cada regla vive en su propio archivo y tiene su archivo `_test.rego` con un caso que pasa y uno que falla:

| Archivo | Regla |
|---------|-------|
| `storage_public.rego` | Buckets con `public_access_prevention = "enforced"` y sin IAM para `allUsers` / `allAuthenticatedUsers` |
| `labels.rego` | Etiquetas `env`, `app`, `owner`, `cost_center`, `managed_by` en todo recurso etiquetable |
| `vm_external_ip.rego` | VMs y plantillas sin `access_config` (sin IP externa) |
| `sql_public_ip.rego` | Cloud SQL con `ipv4_enabled = false` |
| `sa_keys.rego` | Prohibido `google_service_account_key` |
| `firewall_open.rego` | Ninguna regla de ingreso permitida desde `0.0.0.0/0` o `::/0` |
| `gke_private.rego` | GKE con `enable_private_nodes = true` |

`testdata/plan-pass.json` debe pasar y `testdata/plan-fail.json` debe ser rechazado; el job `policy-tests` comprueba ambos.

## E2E

Criterio de aceptación: una VM de prod llega a on-prem por IP privada y resuelve `*.corp.acme.internal`.

```bash
PROJECT_ID=<app_project_id de prod> MIG_NAME=<mig_name de prod> ONPREM_IP=<IP de la VM on-prem> \
  gcp-datacenter/tests/e2e/connectivity.sh
```

Los valores salen de `terraform output` de `4-projects/envs/prod` y `5-workloads/envs/prod`.
El script usa IAP, así que la VM no necesita IP externa.
