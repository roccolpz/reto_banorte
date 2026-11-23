# Runbook: primer despliegue en una organización de prueba

Cuándo: primera vez que la landing zone se aplica en GCP, en una organización desechable, para encontrar lo que el
código local no detecta (permisos, cuotas, APIs, tiempos de GCP). Los comandos de cada paso están en
`bootstrap-first-apply.md`; este documento fija el orden, las decisiones de prueba y qué hacer con los errores.

## 1. Lo que hay que conseguir antes (a mano)

| Qué | Para qué | Cómo comprobar |
|-----|----------|----------------|
| Organización de GCP (Cloud Identity o Workspace con dominio) | Carpetas, org policies, VPC-SC, SCC | `gcloud organizations list` muestra el ID |
| Cuenta con Organization Administrator, Folder Creator, Project Creator, Billing Account User y Security Admin en la organización | Primer apply de 0-bootstrap | `gcloud organizations get-iam-policy <ORG_ID>` |
| Cuenta de facturación con crédito | Todos los proyectos | `gcloud billing accounts list` |
| Cuota de proyectos ligados a esa cuenta de facturación: al menos 15 | Se crean unos 14 proyectos (semilla, 4 comunes, 3 net-host, app y datos por entorno) | Las cuentas nuevas suelen permitir pocos; pedir aumento en la consola de facturación |
| Política de Access Context Manager de la organización: su número, o ninguna | 2-security | `gcloud access-context-manager policies list --organization=<ORG_ID>` |
| Security Command Center activado a nivel organización (Standard) | 1-org crea notificaciones de SCC | Paso 5 de `bootstrap-first-apply.md` |
| `gcloud` y Terraform 1.17.2 en la máquina que aplica | Todo | `terraform version` |

Si la organización la dan los profesores, confirmar con ellos que se pueden crear carpetas, proyectos y una
política de acceso (solo puede haber una por organización).

## 2. Decisiones para la prueba

- `audit_retention_locked = false`. Si es `true`, el bucket de auditoría no se puede borrar hasta que venza la
  retención. En el pipeline: variable `AUDIT_RETENTION_LOCKED=false` antes del primer apply.
- `vpc_sc_enforce = { dev = false, qa = false, prod = false }`: el perímetro solo registra violaciones.
- 2-security: si `policies list` devuelve una política, `create_access_policy = false` y su número en
  `access_policy_name`; si no hay, `create_access_policy = true` y `org_id`.
- `groups` vacío en 1-org si los grupos no existen todavía: no se crean bindings humanos.
- Aplicar a mano (opción B de `bootstrap-first-apply.md`), no por el pipeline: los errores se ven y se
  reintentan más rápido. El pipeline se prueba después, con la landing zone ya creada.
- Desplegar dev completo primero. qa y prod solo cuando dev quede sin errores: prod es lo más caro (GKE DR en
  us-east4, Cloud SQL con réplica).

## 3. Orden

Cada línea es una raíz. En cada una: `cp terraform.tfvars.example terraform.tfvars`, editar, `terraform init`
(con `-backend-config="bucket=$BUCKET"` desde 1-org), `terraform plan -out=tfplan`, `terraform apply tfplan`.

1. `0-bootstrap` con estado local, luego migrar el estado al bucket (pasos 1 y 2 del runbook de bootstrap).
2. Activar SCC si no está activo.
3. `1-org`
4. `2-security`
5. `3-networks/hub`
6. `3-networks/envs/dev`, `4-projects/envs/dev`, `5-workloads/envs/dev`
7. `2-security` otra vez: mete dev en su perímetro y crea accesores de secretos y egreso (ADR 0007-f, 0013-g).
8. Probar dev: `tests/e2e/connectivity.sh` y un segundo `plan` sin cambios en cada raíz.
9. Repetir 6 y 7 para qa, luego para prod.

Guardar la salida de cada apply para revisarla:

```bash
mkdir -p ~/lz-logs
terraform apply tfplan 2>&1 | tee ~/lz-logs/$(basename "$PWD")-$(date +%H%M).log
```

## 4. Errores esperados

| Síntoma | Causa | Qué hacer |
|---------|-------|-----------|
| 1-org falla al crear la notificación de SCC | SCC no activado | Activarlo y reaplicar 1-org |
| `3-networks/hub` se detiene en la postcondición "GCP aún no reservó la IP DNS_RESOLVER…" | GCP tarda en reservar la IP | Esperar un minuto y reaplicar |
| `SERVICE_DISABLED` o "API has not been used in project" justo después de crear un proyecto | La API tarda en propagarse | Esperar 1–2 minutos y reaplicar |
| 403 al leer el estado de otra etapa | Falta el prefijo en `local.state_read_prefixes` (0-bootstrap) | Solo pasa con las SA del pipeline; agregar el prefijo y aplicar 0-bootstrap |
| "Quota exceeded" o "billing account … project quota" | Cuota de proyectos o de CPU/IPs | Pedir aumento y reaplicar |
| Error de org policy (`constraints/...`) al crear un recurso | Una política de 1-org bloquea algo que una etapa necesita | Anotar la política y el recurso; se corrige en el código |
| 5-workloads no encuentra la tag key `<prefix>-dev-net-fw` | 3-networks/dev no se aplicó o falta `tagViewer` | Aplicar 3-networks/dev primero |

Cualquier otro error: guardar el log y corregir en el código, no a mano en la consola, para que el siguiente
apply no lo revierta.

## 5. Limpieza

En orden inverso: 5-workloads, 4-projects, 3-networks de cada entorno (ver `destroy-dev.md`), luego
`3-networks/hub`, `2-security`, `1-org` y al final `0-bootstrap`. Las llaves KMS no se borran (quedan programadas
para destrucción) y los proyectos quedan 30 días en `DELETE_REQUESTED`; por eso un nuevo intento usa otro
`suffix`. Los túneles VPN, los clústeres GKE y Cloud SQL cobran por hora: destruirlos al terminar cada sesión de
prueba si no se van a usar.
