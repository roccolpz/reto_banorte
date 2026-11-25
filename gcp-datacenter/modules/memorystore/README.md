# Módulo `memorystore`

Instancia de Memorystore for Redis con IP privada por el acceso a servicios privados de la VPC compartida (el mismo
peering que usa Cloud SQL, creado en `3-networks`), AUTH activo y cifrado en tránsito (`SERVER_AUTHENTICATION`). Por
defecto es `BASIC` de 1 GB (la opción más barata); `STANDARD_HA` agrega una réplica en otra zona.

El cifrado en reposo usa llaves de Google: el contrato de llaves de `2-security` no tiene una llave `redis` y la
instancia guarda caché, no datos de origen.

## Uso

```hcl
module "memorystore" {
  source     = "../../modules/memorystore"
  name       = "acme-prod-data-redis"
  project_id = "acme-prod-data-xxxx"
  network    = "projects/acme-prod-net-host-xxxx/global/networks/acme-prod-net-vpc"
  labels     = { env = "prod", app = "landing-zone", owner = "plataforma", cost_center = "TI-001", managed_by = "terraform" }
}
```

Ejemplo completo en [examples/basic](examples/basic/main.tf).

## Entradas

| Nombre | Descripción | Tipo | Default | Requerido |
|---|---|---|---|:-:|
| name | Nombre de la instancia. | `string` | n/a | sí |
| project_id | Proyecto. | `string` | n/a | sí |
| region | Región. | `string` | `"us-central1"` | no |
| network | VPC con acceso a servicios privados. | `string` | n/a | sí |
| tier | `BASIC` o `STANDARD_HA`. | `string` | `"BASIC"` | no |
| memory_size_gb | Memoria en GB. | `number` | `1` | no |
| redis_version | Versión de Redis. | `string` | `"REDIS_7_2"` | no |
| labels | Etiquetas obligatorias. | `map(string)` | n/a | sí |

## Salidas

| Nombre | Descripción |
|---|---|
| instance_name | Nombre de la instancia. |
| host | IP privada. |
| port | Puerto. |

## Pruebas

```sh
terraform init -backend=false && terraform test
```
