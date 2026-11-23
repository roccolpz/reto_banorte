# Runbook: túnel HA VPN o sesión BGP caída

Síntomas: alerta de túnel o BGP caído, VMs que no llegan a `192.168.0.0/16`, fallas de DNS de `corp.acme.internal`,
`tests/e2e/connectivity.sh` en rojo.

Impacto: con un túnel arriba no hay pérdida de servicio (HA VPN con dos túneles). Con los dos abajo, las cargas pierden
on-prem; el resto de GCP sigue funcionando.

## 1. Ver el estado

```bash
HUB_PROJECT=acme-common-net-hub-xxxx
REGION=us-central1

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
- Las reglas de firewall de la VPC del entorno deben permitir el tráfico desde `192.168.0.0/16`.

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
