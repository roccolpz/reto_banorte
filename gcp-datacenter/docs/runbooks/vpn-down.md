# Runbook: túnel HA VPN o sesión BGP caída

Síntomas: alerta de túnel o BGP caído, VMs que no llegan a `192.168.0.0/16`, fallas de DNS de `corp.acme.internal`,
`tests/e2e/connectivity.sh` en rojo.

Impacto: con un túnel arriba no hay pérdida de servicio (HA VPN con dos túneles). Con los dos abajo, las cargas pierden
on-prem; el resto de GCP sigue funcionando.

## 1. Ver el estado

El hub tiene un HA VPN y un Cloud Router por región (`us-central1` y `us-east4`), cada uno con dos túneles. Revisa
las dos regiones: una caída en una sola región no corta on-prem mientras la otra siga arriba.

```bash
HUB_PROJECT=acme-common-net-hub-xxxx
REGION=us-central1   # repetir con us-east4

gcloud compute vpn-tunnels list --project "$HUB_PROJECT" \
  --format 'table(name,region,status,detailedStatus,peerIp)'

gcloud compute routers list --project "$HUB_PROJECT" --regions "$REGION"
gcloud compute routers get-status <router-del-hub> --project "$HUB_PROJECT" --region "$REGION" \
  --format 'yaml(result.bgpPeerStatus)'
```

| `status` del túnel | Causa probable |
|--------------------|----------------|
| `ESTABLISHED` y BGP `UP` | El túnel está bien: revisa rutas y firewall (paso 3) |
| `ESTABLISHED` y BGP `DOWN` | ASN, IP de enlace (169.254.x.x) o MD5 no coinciden entre los dos routers |
| `NO_INCOMING_PACKETS`, `NEGOTIATION_FAILURE` | El otro extremo no responde o el secreto compartido no coincide |
| `FIRST_HANDSHAKE`, `WAITING_FOR_FULL_CONFIG` | Falta configurar el otro extremo o el gateway externo |

## 2. Revisar el lado on-prem

En este repositorio on-prem es la VPC `onprem-sim` (ADR 0005-e). Repite el paso 1 en su proyecto. Ambos lados deben
mostrar el mismo par de túneles y los ASN `65001` (on-prem) y `64514` (hub).

## 3. Rutas y firewall

```bash
gcloud compute routers get-status <router-del-hub> --project "$HUB_PROJECT" --region "$REGION" \
  --format 'yaml(result.bestRoutes)'
```

- Debe haber rutas aprendidas hacia `192.168.0.0/16`.
- En NCC, el spoke híbrido de los túneles debe estar `ACTIVE`:
  `gcloud network-connectivity spokes list --project "$HUB_PROJECT"`.
- El firewall del entorno es una política de firewall de red (`<prefix>-<env>-net-fwp`) con etiquetas seguras
  `gke-nodes` y `vm`. On-prem solo llega a TCP 80 y 443 de las cargas con alguna de esas etiquetas, y la regla
  `allow-onprem` registra cada conexión. Otro puerto, o una VM sin etiqueta, se bloquea a propósito: no es la VPN.
  Revisa los aciertos en Logging (`jsonPayload.rule_details.reference` con el nombre de la regla) y las reglas con
  `gcloud compute network-firewall-policies rules list --firewall-policy <prefix>-<env>-net-fwp --global-firewall-policy --project <host>`.
- DNS de `corp.acme.internal`: si el hub se acaba de crear y el apply se detuvo en la postcondición del forwarder
  DNS, espera un minuto y vuelve a correr el apply de `3-networks/hub` (ver `bootstrap-first-apply.md`).

## 4. Corregir

- **Configuración distinta a la del código**: el apply la restaura. Corre el workflow `drift` o un plan de
  `3-networks/hub`; si muestra cambios, aplica por el pipeline.
- **Secreto compartido rotado de un solo lado**: el secreto vive en Secret Manager; vuelve a aplicar
  `3-networks/hub` para que los dos lados usen la versión vigente (ver `rotate-secret.md`).
- **Túnel atascado**: forzar la renegociación recreándolo con `terraform apply -replace=<dirección del túnel>`
  en `3-networks/hub`, por PR, un túnel a la vez para no perder los dos.

## 5. Cerrar

- `tests/e2e/connectivity.sh` en verde.
- Anota causa y solución en el incidente.
