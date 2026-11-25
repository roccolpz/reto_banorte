# Módulo `cloud-run`

Servicio de Cloud Run (v2) que escala a cero, con cuenta de servicio dedicada e ingreso limitado al balanceador
(`INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER`) o a la red interna. El ingreso público directo (`INGRESS_TRAFFIC_ALL`) se
rechaza en la validación. Como la org policy `iam.allowedPolicyMemberDomains` no deja dar `roles/run.invoker` a
`allUsers`, el servicio se publica con `invoker_iam_disabled = true` y el acceso lo controlan el ingreso y Cloud Armor
(módulo [`load-balancer`](../load-balancer/README.md)).

## Uso

```hcl
module "cloud_run" {
  source                = "../../modules/cloud-run"
  name                  = "acme-prod-app-run"
  project_id            = "acme-prod-app-xxxx"
  service_account_email = "cloud-run@acme-prod-app-xxxx.iam.gserviceaccount.com"
  labels                = { env = "prod", app = "landing-zone", owner = "plataforma", cost_center = "TI-001", managed_by = "terraform" }
}
```

Ejemplo completo en [examples/basic](examples/basic/main.tf).

## Entradas

| Nombre | Descripción | Tipo | Default | Requerido |
|---|---|---|---|:-:|
| name | Nombre del servicio. | `string` | n/a | sí |
| project_id | Proyecto del servicio. | `string` | n/a | sí |
| region | Región. | `string` | `"us-central1"` | no |
| image | Imagen del contenedor. | `string` | `us-docker.pkg.dev/cloudrun/container/hello` | no |
| service_account_email | Cuenta de servicio del servicio. | `string` | n/a | sí |
| ingress | `INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER` o `INGRESS_TRAFFIC_INTERNAL_ONLY`. | `string` | `"INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"` | no |
| invoker_iam_disabled | Invocar sin `roles/run.invoker`. | `bool` | `true` | no |
| min_instances | Instancias mínimas. | `number` | `0` | no |
| max_instances | Instancias máximas. | `number` | `2` | no |
| cpu | Límite de CPU. | `string` | `"1"` | no |
| memory | Límite de memoria. | `string` | `"512Mi"` | no |
| deletion_protection | Protección contra borrado. | `bool` | `false` | no |
| labels | Etiquetas obligatorias. | `map(string)` | n/a | sí |

## Salidas

| Nombre | Descripción |
|---|---|
| service_name | Nombre del servicio. |
| service_uri | URI `run.app`. |
| region | Región (para el NEG serverless). |

## Pruebas

```sh
terraform init -backend=false && terraform test
```
