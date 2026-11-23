# 3-networks

Red hub-and-spoke de la landing zone. Orden de aplicación: `hub`, luego `envs/dev`, `envs/qa`, `envs/prod`.

```bash
terraform init -backend-config="bucket=<state_bucket>"
terraform plan
```

## Raíces

| Raíz | Estado (`prefix`) | Qué crea |
|---|---|---|
| `hub/` | `3-networks/hub` | VPC del hub, hub de NCC (STAR), VPC `onprem-sim` con su zona `corp.acme.internal.`, HA VPN y Cloud Router por región de `vpn_regions` (default us-central1 y us-east4) y reenvío DNS |
| `envs/<env>/` | `3-networks/<env>` | Shared VPC del entorno (módulo local `modules/env`): subredes, NAT, PSA, DNS, política de firewall con etiquetas seguras y VPC spoke de NCC |

Los entornos solo difieren en `local.env`; el direccionamiento del contrato (§5) vive en `modules/env/main.tf`.
Cada raíz `envs/<env>` lee el estado de 1-org y del hub y pasa valores planos al módulo, que no lee
estado remoto (mismo patrón que 4-projects y 5-workloads).

## Firewall por etiqueta segura

Cada entorno tiene una política de firewall de red (`<prefix>-<env>-net-fwp`) asociada a su VPC y
una llave de etiqueta segura `<prefix>-<env>-net-fw` con los valores `gke-nodes` y `vm`. La salida
`secure_tag_values` da `tagValues/<id>` de cada uno; 5-workloads los vincula a nodos y VM.

| Regla | Prioridad | Origen | Puertos | Destino |
|---|---|---|---|---|
| `deny-other-envs` | 900 | `/16` de los otros entornos | todos | toda la VPC (deny, con logging) |
| `allow-gke-master` | 1000 | `172.16.<octeto>.0/28` | TCP 443, 10250 | `gke-nodes` |
| `allow-internal` | 1010 | `/16` propios | todos | `gke-nodes`, `vm` |
| `allow-onprem` | 1020 | `192.168.0.0/16` | TCP 80, 443 | `gke-nodes`, `vm` (con logging) |
| `allow-iap` | 1030 | `35.235.240.0/20` | TCP 22, 3389 | `gke-nodes`, `vm` (con logging) |
| `allow-health-checks` | 1040 | `130.211.0.0/22`, `35.191.0.0/16` | TCP | `gke-nodes`, `vm` |
| `deny-all-ingress` | 65000 | `0.0.0.0/0` | todos | toda la VPC (deny, con logging) |

On-prem solo inicia conexiones hacia las apps por HTTP/HTTPS. El tráfico de GCP hacia on-prem
(pruebas e2e, DNS) sale de GCP y su respuesta entra por estado de conexión, sin regla de ingreso.
Una instancia sin etiqueta solo recibe lo que no niegan los deny; en la práctica, nada.

## Conectividad (NCC)

Topología **STAR** en un solo hub:

- grupo `center`: spokes híbridos con los túneles HA VPN hacia `onprem-sim`
  (`include_import_ranges = ["ALL_IPV4_RANGES"]`, sin site-to-site);
- grupo `edge`: un VPC spoke por entorno, auto-aceptado para los proyectos host de 1-org.

Cada entorno aprende las rutas on-prem del center, pero NCC no instala rutas entre spokes edge:
dev, qa y prod no se ven entre sí. Además, el firewall de cada entorno niega con logging los rangos
de los otros entornos. No hace falta peering ni un ADR de excepción.

## Requisitos de otras etapas

- `onprem-sim` y las VPN viven en el proyecto `net_hub`: NCC exige que los túneles de un spoke
  híbrido estén en el mismo proyecto que el hub.
- IAM que 1-org ya otorga: `roles/dns.peer` en `net_hub` para cada `3-networks-<env>`.
- IAM que falta en 1-org (`iam.tf`):
  - `3-networks-hub`: `roles/networkconnectivity.hubAdmin` en `net_hub` (hub, grupo y spokes híbridos).
  - `3-networks-<env>`: `roles/networkconnectivity.spokeAdmin` en su proyecto host y
    `roles/networkconnectivity.groupUser` en `net_hub` (unir el VPC spoke al grupo `edge`).
- `3-networks-<env>`: `roles/resourcemanager.tagAdmin` en su proyecto host (crear la llave y
  los valores de etiqueta segura). `compute.securityAdmin` ya cubre la política de firewall.
- 4-projects: `roles/resourcemanager.tagUser` sobre cada valor de `secure_tag_values` para las
  cuentas que crean nodos GKE y VM.
- APIs en `net_hub` y proyectos host: `compute`, `dns`, `networkconnectivity`, `servicenetworking`,
  `cloudresourcemanager` (etiquetas seguras).

## Riesgos abiertos

- **Reenvío DNS hacia onprem-sim.** El hub reenvía `corp.acme.internal.` a la IP del forwarder
  entrante de `onprem-sim` (leída con `google_compute_addresses` después de crear la política). La
  documentación de Cloud DNS solo describe destinos en la misma VPC o en on-prem real por VPN; un
  forwarder entrante en otra VPC detrás de HA VPN no está documentado. Si no resuelve, poner en
  `onprem_dns_target_ips` la IP de una VM DNS en `192.168.10.0/24`.
- **IP del forwarder aún no reservada.** Si GCP no reservó la IP `DNS_RESOLVER` cuando se lee, el
  apply del hub falla con un mensaje que lo explica (postcondición). Volver a correr el apply, o
  definir `onprem_dns_target_ips`.
- **Secreto de las VPN.** Se genera con `random_password` y solo vive en el estado (bucket con
  CMEK). Restringir la lectura del bucket.
