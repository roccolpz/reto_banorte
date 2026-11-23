# 1-org

Jerarquía de la organización, proyectos comunes, políticas de organización, firewall jerárquico,
IAM y el sink de auditoría. Corre con la SA `sa-tf-1-org` creada por `0-bootstrap`.

## Qué crea

- Carpetas `common`, `dev`, `qa` y `prod` bajo la organización. La carpeta `bootstrap` la crea
  `0-bootstrap`; esta etapa solo la lee de su estado remoto.
- Proyectos de `common` (`net_hub`, `logging`, `security`, `backup`) y un proyecto `net-host`
  por entorno, todos con `modules/project-factory`. 3-networks los habilita como host de Shared VPC.
- Políticas de organización (API v2):
  - `compute.vmExternalIpAccess`: denegada para todas las VM.
  - `iam.disableServiceAccountKeyCreation`, `compute.requireShieldedVm`,
    `storage.publicAccessPrevention`, `sql.restrictPublicIp`, `compute.skipDefaultNetworkCreation`.
  - `gcp.resourceLocations`: `in:us-central1-locations` e `in:us-east4-locations`.
  - `iam.allowedPolicyMemberDomains`: solo si `allowed_policy_member_customer_ids` no está vacío.
- Firewall jerárquico asociado a la organización: permite IAP (`35.235.240.0/20`, tcp 22 y 3389)
  y health checks (`35.191.0.0/16`, `130.211.0.0/22`); el resto pasa (`goto_next`) a las reglas de cada VPC.
- IAM:
  - Grupos humanos de `var.groups` (Fase 3, §3.2). Si el mapa está vacío no se crea ningún binding.
  - SAs de las etapas 2 a 5, con roles acotados a su carpeta o proyecto (ver `iam.tf`).
    Las SAs de 1-org y de plan reciben sus roles en 0-bootstrap.
- Sink agregado de la organización (`include_children = true`) con los logs de auditoría hacia un
  bucket en el proyecto `logging`, con retención de `audit_retention_days`.

## Ejecución

```sh
cp terraform.tfvars.example terraform.tfvars   # completar valores
terraform init -backend-config="bucket=<state_bucket>"
terraform plan
terraform apply
```

El proveedor factura las cuotas al proyecto semilla (`billing_project` con `user_project_override`).

## Advertencias

- `audit_retention_locked = true` es irreversible: el bucket no se puede borrar ni acortar su
  retención hasta que venza. Dejarlo en `false` mientras el entorno sea de prueba.
- `gcp.resourceLocations` solo permite los grupos de us-central1 y us-east4. Un bucket
  dual-region o multi-region (por ejemplo `US`) quedará bloqueado; si se necesita, agregar
  el valor correspondiente a la política.
- Los nombres de rol de `iam.tf` no se verificaron contra la API (no hay credenciales en el
  equipo de construcción); el primer `plan` real los valida.

## Entradas

| Nombre | Descripción | Tipo | Default |
|---|---|---|---|
| org_id | ID numérico de la organización | string | n/a |
| billing_account | Cuenta de facturación | string | n/a |
| state_bucket | Bucket de estado de 0-bootstrap | string | n/a |
| suffix | Sufijo hexadecimal de 4 caracteres | string | n/a |
| labels | Etiquetas base (app, owner, cost_center) | map(string) | n/a |
| prefix | Prefijo de la empresa | string | `"acme"` |
| region | Región del bucket de auditoría | string | `"us-central1"` |
| groups | Correos de grupos humanos | map(string) | `{}` |
| allowed_policy_member_customer_ids | IDs de cliente permitidos en IAM | list(string) | `[]` |
| audit_retention_days | Retención del bucket de auditoría | number | `365` |
| audit_retention_locked | Bloquea la retención (irreversible) | bool | `false` |

## Salidas

| Nombre | Descripción |
|---|---|
| folder_ids | Carpetas bootstrap, common, dev, qa y prod (`folders/<id>`) |
| common_project_ids | Proyectos net_hub, logging, security y backup |
| net_host_project_ids | Proyecto de red por entorno |
| audit_log_bucket | Bucket de auditoría |

## Pruebas

`terraform test` usa un proveedor simulado y un estado de 0-bootstrap simulado; no toca GCP.
