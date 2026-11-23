# 3-networks

Red hub-and-spoke de la landing zone. Orden de aplicación: `hub`, luego `envs/dev`, `envs/qa`, `envs/prod`.

```bash
terraform init -backend-config="bucket=<state_bucket>"
terraform plan
```

## Raíces

| Raíz | Estado (`prefix`) | Qué crea |
|---|---|---|
| `hub/` | `3-networks/hub` | VPC del hub, hub de NCC (STAR), VPC `onprem-sim` con su zona `corp.acme.internal.`, HA VPN por región de `vpn_regions` y reenvío DNS |
| `envs/<env>/` | `3-networks/<env>` | Shared VPC del entorno (módulo local `modules/env`): subredes, NAT, PSA, DNS, firewall y VPC spoke de NCC |

Los entornos solo difieren en `local.env`; el direccionamiento del contrato (§5) vive en `modules/env/main.tf`.

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
- La SA de cada `3-networks-<env>` necesita, sobre el proyecto `net_hub`:
  `roles/dns.peer` (zona de peering de `corp.acme.internal.`) y permiso para crear spokes en el hub
  (`roles/networkconnectivity.spokeAdmin` o equivalente). Los otorga 0-bootstrap o 1-org.
- APIs en `net_hub` y proyectos host: `compute`, `dns`, `networkconnectivity`, `servicenetworking`.

## Riesgos abiertos

- **Reenvío DNS hacia onprem-sim.** El hub reenvía `corp.acme.internal.` a la IP del forwarder
  entrante de `onprem-sim` (leída con `google_compute_addresses` después de crear la política). La
  documentación de Cloud DNS solo describe destinos en la misma VPC o en on-prem real por VPN; un
  forwarder entrante en otra VPC detrás de HA VPN no está documentado. Si no resuelve, poner en
  `onprem_dns_target_ips` la IP de una VM DNS en `192.168.10.0/24`.
- **Secreto de las VPN.** Se genera con `random_password` y solo vive en el estado (bucket con
  CMEK). Restringir la lectura del bucket.
