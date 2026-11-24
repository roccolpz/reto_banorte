# ADR 0005-e: On-premises simulado con una VPC conectada por HA VPN

- Estado: aceptada
- Fecha: 2026-11-23

## Contexto

La arquitectura es híbrida: las cargas en GCP deben llegar al centro de datos por IP privada y resolver nombres de
`corp.acme.internal`. El equipo no tiene un sitio físico ni un equipo de red con IPsec y BGP. Uno de los criterios de
aceptación es demostrar esa conectividad.

## Decisión

- On-premises se simula con una VPC `onprem-sim` en GCP, con la subred `192.168.10.0/24` (rango `192.168.0.0/16`)
  en us-central1 y un Cloud Router con ASN `65001`.
- El hub (`10.0.0.0/16`, Cloud Router ASN `64514`) se conecta a `onprem-sim` con HA VPN: dos túneles, BGP dinámico
  y SLA de 99.99 % con la topología de dos interfaces.
- Los túneles se registran como spoke híbrido de Network Connectivity Center, así las VPC de entorno aprenden las rutas
  de on-prem a través del hub.
- Una VM en `onprem-sim` hace de servidor (HTTP y DNS de `corp.acme.internal`). Cloud DNS reenvía esa zona hacia ella.
- La prueba `tests/e2e/connectivity.sh` comprueba ping, HTTP y DNS desde una VM de prod.

## Alternativas descartadas

- **VPN clásica (Classic VPN)**: sin SLA de 99.99 % y con rutas estáticas; no representa lo que se usaría en producción.
- **Un router virtual (p. ej. strongSwan o VyOS) en otra nube o en una laptop**: más realista, pero depende de equipo y
  red fuera del control del equipo, y no se puede reproducir con Terraform.
- **VPC peering entre hub y `onprem-sim`**: no prueba IPsec, BGP ni la propagación por NCC.
- **Cloud Interconnect**: fuera de alcance (ADR 0001) y requiere un sitio de colocación.

## Consecuencias

- La conectividad híbrida se demuestra de punta a punta con el mismo código que se usaría contra un equipo real:
  para conectar un sitio real se cambia el lado `onprem-sim` por un `google_compute_external_vpn_gateway`.
- Los túneles cuestan por hora en ambos lados; `destroy` de esta parte ahorra costo cuando no se usa.
- La latencia y las fallas de un enlace real no se reproducen; el runbook `vpn-down.md` cubre la operación.
